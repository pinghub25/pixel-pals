import ActivityKit
import SwiftUI
import WidgetKit

@main
struct PetWidgetBundle: WidgetBundle {
    var body: some Widget {
        PetLiveActivity()
        PetWidget()
    }
}

/// The pet pops in with a little bounce whenever its emotion changes. Live Activities can't run
/// their own animation loop, so this is a one-shot transition the system plays on each update.
private struct IslandPet: View {
    let kind: PetKind
    let emotion: PetEmotion
    var accessory: Accessory?
    /// In the Dynamic Island the phone is in use, so the pet tilts its head, curious.
    var curious = false
    @Environment(\.isLuminanceReduced) private var screenDimmed

    var body: some View {
        // When the Lock Screen dims to Always-On, iOS redraws this view dimmed: the pet falls asleep.
        // No update from the app is needed, so this costs no battery.
        let asleep = screenDimmed
        let tilt = curious && !asleep && emotion != .sad && emotion != .sleepy
        PixelPetView(kind: kind, frame: asleep ? 1 : emotion.frame, accessory: accessory)
            .rotationEffect(.degrees(tilt ? -12 : 0))
            .overlay(alignment: .topTrailing) {
                if asleep {
                    Text("z")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                        .offset(x: 6, y: -4)
                }
            }
            .id(asleep ? nil : emotion)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.5, anchor: .bottom).combined(with: .opacity),
                removal: .opacity
            ))
            .animation(.spring(response: 0.45, dampingFraction: 0.55), value: emotion)
    }
}

private struct EmotionIcon: View {
    let emotion: PetEmotion

    var body: some View {
        Image(systemName: emotion.symbol)
            .foregroundStyle(emotion.color)
            .contentTransition(.symbolEffect(.replace))
            .animation(.default, value: emotion)
    }
}

private struct CareBars: View {
    let state: PetAttributes.ContentState

    var body: some View {
        if let food = state.food, let fun = state.fun, let energy = state.energy {
            HStack(spacing: 8) {
                bar(food, symbol: "fork.knife", color: .orange)
                bar(fun, symbol: "soccerball", color: .blue)
                bar(energy, symbol: "bolt.fill", color: .purple)
            }
        }
    }

    private func bar(_ value: Double, symbol: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(color)
            ProgressView(value: value)
                .tint(value < PetCare.lowLevel ? .red : color)
        }
    }
}

struct PetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PetAttributes.self) { context in
            let state = context.state
            let emotion = state.emotion(isStale: context.isStale)
            HStack(spacing: 14) {
                IslandPet(kind: state.pet, emotion: emotion, accessory: state.accessory)
                    .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("\(state.name) · \(state.sign.symbol) \(state.sign.name)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(state.pet.color)
                        EmotionIcon(emotion: emotion).font(.caption)
                    }
                    Text(state.message)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    CareBars(state: state)
                }
                Spacer(minLength: 0)
            }
            .padding()
            .activityBackgroundTint(.black.opacity(0.8))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let state = context.state
            let emotion = state.emotion(isStale: context.isStale)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    IslandPet(kind: state.pet, emotion: emotion, accessory: state.accessory, curious: true)
                        .frame(width: 52, height: 52)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(state.sign.symbol)
                        .font(.title)
                        .foregroundStyle(state.pet.color)
                        .padding(.trailing, 8)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(emotion.line(name: state.name))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(state.pet.color)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        Text(state.message)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                        CareBars(state: state)
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                IslandPet(kind: state.pet, emotion: emotion, accessory: state.accessory, curious: true)
                    .frame(width: 24, height: 24)
            } compactTrailing: {
                // The pet's face already shows the emotion; the right side is the zodiac sign.
                Text(state.sign.symbol)
                    .foregroundStyle(state.pet.color)
            } minimal: {
                IslandPet(kind: state.pet, emotion: emotion, accessory: state.accessory, curious: true)
                    .frame(width: 22, height: 22)
            }
            .keylineTint(emotion.color)
        }
    }
}
