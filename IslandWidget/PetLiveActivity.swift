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

struct PetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PetAttributes.self) { context in
            let state = context.state
            HStack(spacing: 14) {
                PixelPetView(kind: state.pet, frame: 2)
                    .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(state.name) · \(state.sign.symbol) \(state.sign.name)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(state.pet.color)
                    Text(state.message)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .lineLimit(3)
                }
                Spacer(minLength: 0)
            }
            .padding()
            .activityBackgroundTint(.black.opacity(0.8))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    PixelPetView(kind: state.pet, frame: 2)
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
                    Text(String(localized: "A note from \(state.name)", bundle: .app))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(state.pet.color)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(state.message)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 4)
                }
            } compactLeading: {
                PixelPetView(kind: state.pet)
                    .frame(width: 24, height: 24)
            } compactTrailing: {
                Text(state.sign.symbol)
                    .foregroundStyle(state.pet.color)
            } minimal: {
                PixelPetView(kind: state.pet)
                    .frame(width: 22, height: 22)
            }
            .keylineTint(state.pet.color)
        }
    }
}
