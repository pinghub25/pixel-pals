import SwiftUI
import WidgetKit

struct PetEntry: TimelineEntry {
    let date: Date
    let profile: PetProfile?
    let care: PetCare
    let frame: Int
}

/// Reads the profile from the App Group. Widgets can't animate, so a new pose is
/// scheduled every 30 minutes for a day; the message follows each entry's date.
struct PetProvider: TimelineProvider {
    func placeholder(in context: Context) -> PetEntry {
        PetEntry(date: .now, profile: .sample, care: PetCare(), frame: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (PetEntry) -> Void) {
        completion(PetEntry(date: .now, profile: PetStore.load() ?? .sample, care: PetStore.loadCare().at(.now), frame: 2))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PetEntry>) -> Void) {
        let profile = PetStore.load()
        let care = PetStore.loadCare()
        let start = Date.now
        // Levels are projected forward for each entry, so the widget notices hunger on its own.
        let entries = (0..<48).map { step in
            let date = start.addingTimeInterval(Double(step) * 30 * 60)
            let projected = care.at(date)
            let emotion = projected.emotion
            let frame = emotion == .happy || emotion == .content ? (step % 2 == 0 ? 0 : 2) : emotion.frame
            return PetEntry(date: date, profile: profile, care: projected, frame: frame)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct PetWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PetWidget", provider: PetProvider()) { entry in
            PetWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [(entry.profile?.pet.color ?? .gray).opacity(0.35), Color(red: 0.06, green: 0.06, blue: 0.09)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
        }
        .configurationDisplayName("Pixel Pal")
        .description("Your pet with today's message for your sign.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct PetWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PetEntry

    var body: some View {
        if let profile = entry.profile {
            content(profile)
        } else {
            VStack(spacing: 6) {
                PixelPetView(kind: .cat, frame: 1).frame(width: 44, height: 44)
                Text(String(localized: "Open Pixel Pals to adopt a pet", bundle: .app))
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
            }
        }
    }

    @ViewBuilder
    private func content(_ profile: PetProfile) -> some View {
        let message = Motivation.message(for: profile, on: entry.date)
        // Small sizes drop the horoscope's lucky color/number line so the forecast fits.
        let short = message.components(separatedBy: "\n").first ?? message
        switch family {
        case .accessoryRectangular:
            HStack(spacing: 6) {
                PixelPetView(kind: profile.pet, frame: entry.frame, accessory: profile.accessory)
                    .frame(width: 36, height: 36)
                Text(short)
                    .font(.caption)
                    .lineLimit(3)
            }
        case .systemMedium:
            HStack(spacing: 14) {
                VStack(spacing: 6) {
                    PixelPetView(kind: profile.pet, frame: entry.frame, accessory: profile.accessory)
                        .frame(width: 84, height: 84)
                        .overlay(alignment: .topTrailing) { needBubble }
                    HStack(spacing: 3) {
                        miniBar(entry.care.food, .orange)
                        miniBar(entry.care.fun, .blue)
                        miniBar(entry.care.energy, .purple)
                    }
                    .frame(width: 84)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(profile.name) · \(profile.sign.symbol) \(profile.sign.name)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(profile.pet.color)
                    Text(entry.care.need?.line(name: profile.name) ?? message)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .lineLimit(4)
                }
                Spacer(minLength: 0)
            }
        default:
            VStack(spacing: 6) {
                PixelPetView(kind: profile.pet, frame: entry.frame, accessory: profile.accessory)
                    .frame(width: 60, height: 60)
                    .overlay(alignment: .topTrailing) { needBubble }
                Text(entry.care.need?.line(name: profile.name) ?? short)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    @ViewBuilder
    private var needBubble: some View {
        if let need = entry.care.need {
            Image(systemName: need.symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.black)
                .padding(4)
                .background(Circle().fill(.white))
                .offset(x: 6, y: -4)
        }
    }

    private func miniBar(_ value: Double, _ color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.15))
                Capsule().fill(value < PetCare.lowLevel ? .red : color)
                    .frame(width: geo.size.width * value)
            }
        }
        .frame(height: 4)
    }
}
