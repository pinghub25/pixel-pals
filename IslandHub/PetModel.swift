import ActivityKit
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
        reschedule()
    }

    func perform(_ action: PetAction) {
        var updated = care.at(.now)
        updated.apply(action)
        // Pats are frequent; only reload widgets for actions that change the levels much.
        setCare(updated, reloadWidgets: action != .pat)
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
                errorText = String(localized: "Notifications are turned off for Pixel Pals in Settings.", bundle: .app)
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

    private var islandState: PetAttributes.ContentState? {
        guard let profile else { return nil }
        return .init(pet: profile.pet, name: profile.name, sign: profile.sign, message: Motivation.message(for: profile))
    }

    /// The message is only good until midnight; after that iOS shows the activity as stale.
    private var endOfToday: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now)) ?? .now
    }

    private func startIsland() {
        guard activity == nil, let state = islandState else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            errorText = String(localized: "Live Activities are turned off in Settings › Pixel Pals.", bundle: .app)
            return
        }
        do {
            let new = try Activity.request(
                attributes: PetAttributes(),
                content: .init(state: state, staleDate: endOfToday),
                pushType: nil
            )
            attach(new)
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func stopIsland() {
        guard let activity else { return }
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
        self.activity = nil
        islandOn = false
    }

    private func updateIsland() {
        guard let activity, let state = islandState else { return }
        Task { await activity.update(.init(state: state, staleDate: endOfToday)) }
    }

    private func attach(_ activity: Activity<PetAttributes>) {
        self.activity = activity
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
                errorText = String(localized: "Notifications are turned off for Pixel Pals in Settings.", bundle: .app)
            }
        }
    }
}
