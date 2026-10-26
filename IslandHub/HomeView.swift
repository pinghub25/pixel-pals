import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: PetModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var editing = false
    @State private var sent = false
    @State private var action: PetAction?
    @State private var actionStart = Date.distantPast
    @State private var hearts: [Date] = []

    var body: some View {
        if let profile = model.profile {
            content(profile)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { model.refresh() }
                }
        }
    }

    private func content(_ profile: PetProfile) -> some View {
        NavigationStack {
            ScrollView {
                // Re-project the levels every minute so the bars drain while you watch.
                TimelineView(.everyMinute) { timeline in
                    let care = model.care.at(timeline.date)
                    VStack(spacing: 18) {
                        petStage(profile, care: care)
                        header(profile, care: care)
                        careCard(care)
                        accessoriesCard(profile, love: care.love)
                        messageCard(profile)
                        settingsCard(profile)
                        if let error = model.errorText {
                            Text(error).font(.footnote).foregroundStyle(.red)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Pixel Pals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Edit") { editing = true }
            }
            .sheet(isPresented: $editing) {
                ProfileForm(title: "Your pal", buttonTitle: "Save", initial: profile) { updated in
                    var updated = updated
                    updated.accessory = profile.accessory  // the form doesn't edit accessories
                    model.save(updated)
                    editing = false
                }
                .presentationDragIndicator(.visible)
            }
        }
        .tint(profile.pet.color)
    }

    private func petStage(_ profile: PetProfile, care: PetCare) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(LinearGradient(
                    colors: [profile.pet.color.opacity(action == .nap ? 0.12 : 0.35), profile.pet.color.opacity(0.04)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .animation(.easeInOut(duration: 0.6), value: action)
            VStack(spacing: 8) {
                PetStage(kind: profile.pet, action: action, actionStart: actionStart, need: care.need, hearts: hearts, sad: care.emotion == .sad, accessory: profile.accessory)
                    .frame(width: 170, height: 170)
                    .contentShape(Rectangle())
                    .onTapGesture { pat() }
                Text("Tap \(profile.name) to say hi")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 250)
    }

    private func header(_ profile: PetProfile, care: PetCare) -> some View {
        VStack(spacing: 6) {
            Text(profile.name).font(.title.bold())
            Text("\(profile.sign.symbol) \(profile.sign.name) · \(profile.sign.element)")
                .foregroundStyle(profile.pet.color)
            Text(care.emotion.line(name: profile.name))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 16) {
                Label { Text("\(care.streak)-day streak") } icon: { Image(systemName: "flame.fill").foregroundStyle(.orange) }
                Label { Text("\(care.love)") } icon: { Image(systemName: "heart.fill").foregroundStyle(.pink) }
            }
            .font(.footnote.weight(.semibold))
        }
    }

    /// Hearts unlock accessories; tap an unlocked one to wear it, tap again to take it off.
    private func accessoriesCard(_ profile: PetProfile, love: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Accessories").font(.headline)
                Spacer()
                Label("\(love)", systemImage: "heart.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.pink)
            }
            HStack(spacing: 8) {
                ForEach(Accessory.allCases) { accessory in
                    let unlocked = love >= accessory.hearts
                    let worn = profile.accessory == accessory
                    Button {
                        model.wear(worn ? nil : accessory)
                    } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                PixelPetView(kind: profile.pet, accessory: accessory)
                                    .frame(width: 48, height: 48)
                                    .opacity(unlocked ? 1 : 0.25)
                                if !unlocked {
                                    Image(systemName: "lock.fill").foregroundStyle(.secondary)
                                }
                            }
                            Text(unlocked ? accessory.title : "\(accessory.hearts) ♥")
                                .font(.caption2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(worn ? profile.pet.color.opacity(0.25) : .white.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(worn ? profile.pet.color : .clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!unlocked)
                }
            }
            if let next = Accessory.allCases.first(where: { $0.hearts > love }) {
                Text("\(next.title) unlocks at \(next.hearts) ♥ — pet, feed and play to earn hearts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private func careCard(_ care: PetCare) -> some View {
        VStack(spacing: 12) {
            statRow("Food", value: care.food, color: .orange)
            statRow("Fun", value: care.fun, color: .blue)
            statRow("Energy", value: care.energy, color: .purple)
            HStack(spacing: 10) {
                actionButton("Feed", systemImage: "fork.knife", action: .feed)
                actionButton("Play", systemImage: "soccerball", action: .play)
                actionButton("Nap", systemImage: "moon.zzz.fill", action: .nap)
            }
            .padding(.top, 4)
        }
        .card()
    }

    private func statRow(_ title: LocalizedStringKey, value: Double, color: Color) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .frame(width: 80, alignment: .leading)
            ProgressView(value: value)
                .tint(value < PetCare.lowLevel ? .red : color)
        }
    }

    private func actionButton(_ title: LocalizedStringKey, systemImage: String, action newAction: PetAction) -> some View {
        Button { run(newAction) } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage).font(.title3)
                Text(title).font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .disabled(isBusy)
    }

    private func messageCard(_ profile: PetProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(model.dailyContent.resolved(on: .now).title) · \(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(.app)))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(model.todayMessage)
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            NavigationLink {
                MyMessagesView()
            } label: {
                Label("My messages", systemImage: "plus.bubble")
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.top, 4)
        }
        .card()
    }

    private func settingsCard(_ profile: PetProfile) -> some View {
        VStack(spacing: 14) {
            Toggle("Show \(profile.name) in the Dynamic Island", isOn: Binding(
                get: { model.islandOn },
                set: { model.setIsland($0) }
            ))
            HStack {
                Label("Language", systemImage: "globe")
                Spacer()
                Picker("Language", selection: $model.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.title).tag(language)
                    }
                }
                .labelsHidden()
            }
            HStack {
                Label("Daily content", systemImage: "sparkles")
                Spacer()
                Picker("Daily content", selection: $model.dailyContent) {
                    ForEach(DailyContent.allCases) { content in
                        Text(content.title).tag(content)
                    }
                }
                .labelsHidden()
            }
            Toggle("Daily message notification", isOn: $model.reminderOn)
            if model.reminderOn {
                DatePicker("Deliver at", selection: reminderTime, displayedComponents: .hourAndMinute)
            }
            Toggle("Tell me when \(profile.name) needs care", isOn: $model.careAlertsOn)
            Button {
                Task {
                    await model.sendNow()
                    sent = true
                }
            } label: {
                Group {
                    if sent {
                        Label("Sent! Check your notifications", systemImage: "checkmark")
                    } else {
                        Label("Send today's message now", systemImage: "bell.badge")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .card()
    }

    private var isBusy: Bool {
        guard let action else { return false }
        return Date.now.timeIntervalSince(actionStart) < action.duration
    }

    private func run(_ newAction: PetAction) {
        action = newAction
        actionStart = .now
        model.perform(newAction)
        // Clear the action afterwards so the buttons re-enable.
        DispatchQueue.main.asyncAfter(deadline: .now() + newAction.duration) {
            if action == newAction { action = nil }
        }
    }

    private func pat() {
        let now = Date.now
        hearts.removeAll { now.timeIntervalSince($0) > 1.5 }
        hearts.append(now)
        model.perform(.pat)
    }

    private var reminderTime: Binding<Date> {
        Binding {
            Calendar.current.date(byAdding: .minute, value: model.reminderMinutes, to: Calendar.current.startOfDay(for: .now)) ?? .now
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            model.reminderMinutes = (parts.hour ?? 9) * 60 + (parts.minute ?? 0)
        }
    }
}
