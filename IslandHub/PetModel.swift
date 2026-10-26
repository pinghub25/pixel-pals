import ActivityKit
import BackgroundTasks
import SwiftUI
import WidgetKit

/// Owns the profile and keeps the island, widget and notifications in sync with it.
@MainActor
final class PetModel: ObservableObject {
    @Published private(set) var profile: PetProfile? = PetStore.load()
    @Published private(set) var care = PetStore.loadCare()
    @Published private(set) var islandOn = false
    @Published var errorText: String?

    /// Switching re-renders the app and pushes the new language to the widget, island and notifications.
    @Published var language = AppLanguage.current {
        didSet {
            AppLanguage.current = language
            refresh()
        }
    }

    @Published var dailyContent = DailyContent.current {
        didSet {
            DailyContent.current = dailyContent
            refresh()
        }
    }

    @Published private(set) var customMessages = CustomMessages.all

    func addCustomMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        customMessages.append(trimmed)
        CustomMessages.all = customMessages
        refresh()
    }

    func removeCustomMessages(at offsets: IndexSet) {
        customMessages.remove(atOffsets: offsets)
        CustomMessages.all = customMessages
        refresh()
    }

    @Published var careAlertsOn: Bool {
        didSet {
            UserDefaults.standard.set(careAlertsOn, forKey: "careAlertsOn")
            scheduleCareAlert()
        }
    }

    @Published var reminderOn: Bool {
        didSet {
            UserDefaults.standard.set(reminderOn, forKey: "reminderOn")
            reschedule()
        }
    }

    /// Minutes after midnight.
    @Published var reminderMinutes: Int {
        didSet {
            UserDefaults.standard.set(reminderMinutes, forKey: "reminderMinutes")
            reschedule()
        }
    }

    private var activity: Activity<PetAttributes>?

    init() {
        reminderOn = UserDefaults.standard.bool(forKey: "reminderOn")
        reminderMinutes = UserDefaults.standard.object(forKey: "reminderMinutes") as? Int ?? 9 * 60
        careAlertsOn = UserDefaults.standard.bool(forKey: "careAlertsOn")
        if let existing = Activity<PetAttributes>.activities.first {
            attach(existing)
        }
    }

    var todayMessage: String {
        profile.map { Motivation.message(for: $0) } ?? ""
    }

    /// Puts on an unlocked accessory, or takes it off with nil.
    func wear(_ accessory: Accessory?) {
        guard var updated = profile else { return }
        if let accessory, care.love < accessory.hearts { return }
        updated.accessory = accessory
        save(updated)
    }

    func save(_ newProfile: PetProfile) {
        if profile == nil { setCare(PetCare()) }
        profile = newProfile
        PetStore.save(newProfile)
        refresh()
    }

    /// Run on launch and whenever the app returns, so a new day's message reaches everything.
    func refresh() {
        var updated = care.at(.now)
        updated.checkIn(on: .now)
        setCare(updated)
        updateIsland()
        scheduleBackgroundRefresh()
        reschedule()
    }

    func perform(_ action: PetAction) {
        var updated = care.at(.now)
        updated.apply(action)
        // Pats are frequent; only reload widgets for actions that change the levels much.
        setCare(updated, reloadWidgets: action != .pat)
        // Rapid pats would mean an island update per tap; one reaction every few seconds is plenty.
        if action != .pat || Date.now.timeIntervalSince(lastReaction) > Self.reactionLength {
            lastReaction = .now
            updateIsland(reaction: action.reaction)
            endReactionSoon()
        }
    }

    private var reactionEnd: Task<Void, Never>?

    /// iOS doesn't redraw the island when a reaction goes stale, so send one follow-up update.
    /// If the app is leaving the foreground, borrow just those few seconds of background time.
    private func endReactionSoon() {
        reactionEnd?.cancel()
        let backgroundID = UIApplication.shared.beginBackgroundTask(withName: "pet-reaction") {}
        reactionEnd = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.reactionLength))
            if !Task.isCancelled { self?.updateIsland() }
            UIApplication.shared.endBackgroundTask(backgroundID)
        }
    }

    /// Called by iOS in the background (at most around each expected mood change).
    /// Pushes the new mood to the island only if it actually changed, then books the next wake-up.
    func backgroundRefresh() {
        updateIsland()
        scheduleBackgroundRefresh()
    }

    static let refreshTaskID = "com.matsavin.pixelpals.mood"
    private static let reactionLength: TimeInterval = 4
    private var lastReaction = Date.distantPast

    /// One request for when the mood is next expected to change. Nothing in Low Power Mode,
    /// and nothing while the island is off, since only the island needs it.
    private func scheduleBackgroundRefresh() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.refreshTaskID)
        guard activity != nil, !ProcessInfo.processInfo.isLowPowerModeEnabled,
              let next = care.at(.now).nextEmotionChange else { return }
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskID)
        request.earliestBeginDate = max(next, .now.addingTimeInterval(15 * 60))
        try? BGTaskScheduler.shared.submit(request)
    }

    private func setCare(_ newCare: PetCare, reloadWidgets: Bool = true) {
        care = newCare
        PetStore.saveCare(newCare)
        if reloadWidgets { WidgetCenter.shared.reloadAllTimelines() }
        scheduleCareAlert()
    }

    private func scheduleCareAlert() {
        guard let profile else { return }
        guard careAlertsOn, let next = care.nextNeed else {
            DailyReminder.cancelCareAlert()
            return
        }
        Task {
            if await !DailyReminder.scheduleCareAlert(profile: profile, need: next.need, at: next.date) {
                careAlertsOn = false
                errorText = String(localized: "Notifications are turned off for Pixel Zodiac in Settings.", bundle: .app)
            }
        }
    }

    func setIsland(_ on: Bool) {
        on ? startIsland() : stopIsland()
    }

    func sendNow() async {
        guard let profile else { return }
        await DailyReminder.sendNow(profile: profile)
    }

    // MARK: - Dynamic Island

    private func islandState(reaction: PetEmotion? = nil) -> PetAttributes.ContentState? {
        guard let profile else { return nil }
        let now = care.at(.now)
        return .init(
            pet: profile.pet, name: profile.name, sign: profile.sign, message: Motivation.message(for: profile),
            mood: now.emotion, reaction: reaction,
            // Rounded so tiny drains don't count as a change worth an update.
            food: (now.food * 20).rounded() / 20, fun: (now.fun * 20).rounded() / 20, energy: (now.energy * 20).rounded() / 20,
            accessory: profile.accessory
        )
    }

    private var lastIslandState: PetAttributes.ContentState?

    /// The message is only good until midnight; after that iOS shows the activity as stale.
    private var endOfToday: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now)) ?? .now
    }

    private func startIsland() {
        guard activity == nil, let state = islandState() else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            errorText = String(localized: "Live Activities are turned off in Settings › Pixel Zodiac.", bundle: .app)
            return
        }
        do {
            let new = try Activity.request(
                attributes: PetAttributes(),
                content: .init(state: state, staleDate: endOfToday),
                pushType: nil
            )
            attach(new)
            lastIslandState = state
            errorText = nil
            scheduleBackgroundRefresh()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func stopIsland() {
        guard let activity else { return }
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
        self.activity = nil
        islandOn = false
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.refreshTaskID)
    }

    /// Sends a new state only when something visible changed. A reaction goes stale after a few
    /// seconds, and the island then shows the mood again without another update.
    private func updateIsland(reaction: PetEmotion? = nil) {
        guard let activity, let state = islandState(reaction: reaction), state != lastIslandState else { return }
        lastIslandState = state
        let stale = reaction == nil ? endOfToday : .now.addingTimeInterval(Self.reactionLength)
        Task { await activity.update(.init(state: state, staleDate: stale)) }
    }

    private func attach(_ activity: Activity<PetAttributes>) {
        self.activity = activity
        lastIslandState = activity.content.state
        islandOn = true
        // iOS ends activities after ~8 hours; reflect that in the toggle.
        Task { [weak self] in
            for await update in activity.activityStateUpdates where update == .ended || update == .dismissed {
                if self?.activity?.id == activity.id {
                    self?.activity = nil
                    self?.islandOn = false
                }
            }
        }
    }

    // MARK: - Notifications

    private func reschedule() {
        guard let profile else { return }
        guard reminderOn else {
            DailyReminder.cancel()
            return
        }
        let minutes = reminderMinutes
        Task {
            if await !DailyReminder.schedule(profile: profile, minutes: minutes) {
                reminderOn = false
                errorText = String(localized: "Notifications are turned off for Pixel Zodiac in Settings.", bundle: .app)
            }
        }
    }
}
