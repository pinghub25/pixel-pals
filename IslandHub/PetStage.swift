import SwiftUI

/// Small props drawn in the same pixel style as the pets.
private enum Prop {
    static let heart = [
        ".RR.RR.",
        "RRRRRRR",
        "RRRRRRR",
        ".RRRRR.",
        "..RRR..",
        "...R...",
    ]
    static let apple = [
        "...K...",
        "...KG..",
        ".RRRRR.",
        "RRRWRRR",
        "RRRRRRR",
        "RRRRRRR",
        ".RRRRR.",
    ]
    static let ball = [
        ".BBBB.",
        "BWBBWB",
        "BBBBBB",
        "BBWWBB",
        "BWBBWB",
        ".BBBB.",
    ]
    static let palette: [Character: Color] = [
        "R": Color(red: 0.95, green: 0.3, blue: 0.4),
        "W": .white,
        "K": Color(red: 0.35, green: 0.22, blue: 0.12),
        "G": Color(red: 0.4, green: 0.8, blue: 0.35),
        "B": Color(red: 0.3, green: 0.6, blue: 1.0),
    ]
}

private struct PropSprite: View {
    let rows: [String]

    var body: some View {
        Canvas { context, size in
            let px = size.width / CGFloat(rows[0].count)
            for (y, row) in rows.enumerated() {
                for (x, code) in row.enumerated() {
                    guard let color = Prop.palette[code] else { continue }
                    let rect = CGRect(x: CGFloat(x) * px, y: CGFloat(y) * px, width: px + 0.4, height: px + 0.4)
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .aspectRatio(CGFloat(rows[0].count) / CGFloat(rows.count), contentMode: .fit)
    }
}

/// The pet with its current action: munching an apple, chasing a ball, napping,
/// hearts from taps, or a thought bubble when it needs something.
struct PetStage: View {
    let kind: PetKind
    let action: PetAction?
    let actionStart: Date
    let need: PetNeed?
    let hearts: [Date]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15)) { timeline in
            let now = timeline.date
            let t = now.timeIntervalSinceReferenceDate
            let elapsed = now.timeIntervalSince(actionStart)
            let active = action.flatMap { elapsed < $0.duration ? $0 : nil }

            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                let px = side / 16

                ZStack {
                    pet(active: active, elapsed: elapsed, t: t, px: px)
                        .frame(width: side, height: side)

                    switch active {
                    case .feed:
                        // The apple drops in, then the pet munches it.
                        if elapsed < 0.8 {
                            PropSprite(rows: Prop.apple)
                                .frame(width: px * 4)
                                .offset(y: -side * 0.7 + (elapsed / 0.8) * side * 0.75)
                        }
                    case .play:
                        PropSprite(rows: Prop.ball)
                            .frame(width: px * 3.5)
                            .offset(x: sin(elapsed * 3.5) * px * 6, y: side * 0.38 - abs(sin(elapsed * 7)) * px * 6)
                    case .nap:
                        ForEach(0..<3, id: \.self) { i in
                            let phase = (elapsed * 0.5 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                            Text("z")
                                .font(.system(size: px * (2 + phase * 2), weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .opacity(1 - phase)
                                .offset(x: side * 0.25 + phase * px * 3, y: -side * 0.25 - phase * px * 6)
                        }
                    default:
                        if let need {
                            Image(systemName: need.symbol)
                                .font(.system(size: px * 1.8, weight: .bold))
                                .foregroundStyle(.black)
                                .padding(px * 1.2)
                                .background(Circle().fill(.white))
                                .offset(x: side * 0.4, y: -side * 0.4 + sin(t * 3) * px * 0.5)
                        }
                    }

                    ForEach(hearts.filter { now.timeIntervalSince($0) < 1.2 }, id: \.self) { tapped in
                        let age = now.timeIntervalSince(tapped)
                        let drift = (tapped.timeIntervalSinceReferenceDate * 1000).truncatingRemainder(dividingBy: 12) - 6
                        PropSprite(rows: Prop.heart)
                            .frame(width: px * 3)
                            .offset(x: drift * px, y: -side * 0.35 - age * px * 10)
                            .opacity(1 - age / 1.2)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }

    private func pet(active: PetAction?, elapsed: TimeInterval, t: TimeInterval, px: CGFloat) -> some View {
        let frame: Int
        let hop: Double
        switch active {
        case .feed:
            // Munch: alternate mouth open/closed after the apple lands.
            frame = elapsed < 0.8 ? 0 : (Int(elapsed * 6) % 2 == 0 ? 2 : 0)
            hop = 0
        case .play:
            frame = 2
            hop = abs(sin(elapsed * 7)) * 3
        case .nap:
            frame = 1
            hop = 0
        default:
            // A pet in need stops bouncing and wiggling.
            let wiggle = need == nil && PetMotion.isWiggling(t)
            frame = wiggle ? 2 : PetMotion.idleFrame(t)
            hop = need != nil ? 0 : (wiggle ? PetMotion.wiggleHop(t) : PetMotion.bob(t))
        }
        return PixelPetView(kind: kind, frame: frame)
            .offset(y: -CGFloat(hop) * px)
            .opacity(active == .nap ? 0.85 : 1)
    }
}
