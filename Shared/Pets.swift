import SwiftUI

/// 16×16 pixel pets. Every pet has three frames: 0 idle, 1 blink, 2 happy.
///
/// Sprite legend: K outline, E eye, W white, B body, D shade/accent, L belly,
/// P cheek, R tongue, O beak/feet, G gills, "." transparent.
enum PetKind: String, Codable, Hashable, CaseIterable, Identifiable {
    case cat, dog, bunny, frog, ghost, penguin, axolotl, dino

    var id: String { rawValue }

    var defaultName: String {
        switch self {
        case .cat: "Mochi"
        case .dog: "Kuma"
        case .bunny: "Puff"
        case .frog: "Pip"
        case .ghost: "Boo"
        case .penguin: "Waddle"
        case .axolotl: "Lolo"
        case .dino: "Rexie"
        }
    }

    var species: String {
        switch self {
        case .cat: String(localized: "Cat", bundle: .app)
        case .dog: String(localized: "Dog", bundle: .app)
        case .bunny: String(localized: "Bunny", bundle: .app)
        case .frog: String(localized: "Frog", bundle: .app)
        case .ghost: String(localized: "Ghost", bundle: .app)
        case .penguin: String(localized: "Penguin", bundle: .app)
        case .axolotl: String(localized: "Axolotl", bundle: .app)
        case .dino: String(localized: "Dino", bundle: .app)
        }
    }

    /// Main body color, also used as the pet's accent color in the UI.
    var color: Color {
        switch self {
        case .cat: Color(red: 1.0, green: 0.72, blue: 0.42)
        case .dog: Color(red: 0.93, green: 0.62, blue: 0.32)
        case .bunny: Color(red: 0.97, green: 0.96, blue: 0.98)
        case .frog: Color(red: 0.45, green: 0.82, blue: 0.42)
        case .ghost: Color(red: 0.94, green: 0.93, blue: 1.0)
        case .penguin: Color(red: 0.45, green: 0.6, blue: 0.95)
        case .axolotl: Color(red: 1.0, green: 0.72, blue: 0.82)
        case .dino: Color(red: 0.5, green: 0.8, blue: 0.45)
        }
    }

    func pixelColor(_ code: Character) -> Color? {
        switch code {
        case "K", "E": Color(red: 0.08, green: 0.08, blue: 0.12)
        case "W": .white
        case "P": Color(red: 1.0, green: 0.55, blue: 0.65)
        case "R": Color(red: 0.95, green: 0.35, blue: 0.42)
        case "B": bodyColor
        case "D": shadeColor
        case "L": bellyColor
        case "O", "G": extraColor
        default: nil
        }
    }

    private var bodyColor: Color {
        self == .penguin ? Color(red: 0.22, green: 0.27, blue: 0.42) : color
    }

    private var shadeColor: Color {
        switch self {
        case .cat: Color(red: 0.85, green: 0.5, blue: 0.25)
        case .dog: Color(red: 0.75, green: 0.42, blue: 0.2)
        case .bunny: Color(red: 0.8, green: 0.78, blue: 0.85)
        case .frog: Color(red: 0.28, green: 0.58, blue: 0.27)
        case .ghost: Color(red: 0.72, green: 0.7, blue: 0.88)
        case .penguin: Color(red: 0.15, green: 0.18, blue: 0.3)
        case .axolotl: Color(red: 0.9, green: 0.5, blue: 0.65)
        case .dino: Color(red: 0.97, green: 0.58, blue: 0.3)
        }
    }

    private var bellyColor: Color {
        switch self {
        case .cat: Color(red: 1.0, green: 0.93, blue: 0.82)
        case .dog: Color(red: 1.0, green: 0.95, blue: 0.86)
        case .bunny, .axolotl: Color(red: 1.0, green: 0.88, blue: 0.92)
        case .frog: Color(red: 0.8, green: 0.95, blue: 0.6)
        case .ghost, .penguin: .white
        case .dino: Color(red: 0.88, green: 0.96, blue: 0.62)
        }
    }

    private var extraColor: Color {
        self == .axolotl ? Color(red: 0.95, green: 0.38, blue: 0.58) : Color(red: 1.0, green: 0.62, blue: 0.2)
    }

    func sprite(frame: Int) -> [String] {
        var rows = art.base
        let overrides = switch frame % 3 {
        case 1: art.blink
        case 2: art.happy
        default: [Int: String]()
        }
        for (index, row) in overrides { rows[index] = row }
        return rows
    }

    private var art: (base: [String], blink: [Int: String], happy: [Int: String]) {
        switch self {
        case .cat: (
            [
                "................",
                "..KK........KK..",
                "..KBK......KBK..",
                "..KBPK....KPBK..",
                "..KBBBKKKKBBBK..",
                ".KBBBBBBBBBBBBK.",
                ".KBBBBBBBBBBBBK.",
                ".KBBEWBBBBEWBBK.",
                ".KBBEEBBBBEEBBK.",
                ".KBPBBKBBKBBPBK.",
                ".KBBBBBKKBBBBBK.",
                "..KBBBBBBBBBBK..",
                "..KBLLLLLLLLBK..",
                "..KBLLLLLLLLBK..",
                "..KBBKBBBBKBBK..",
                "...KK.KKKK.KK...",
            ],
            [7: ".KBBBBBBBBBBBBK.", 8: ".KBBKKBBBBKKBBK."],
            [7: ".KBBKKBBBBKKBBK.", 8: ".KBKBBKBBKBBKBK.", 9: ".KBPBKBBBBKBPBK.", 10: ".KBBBBKRRKBBBBK."]
        )
        case .dog: (
            [
                "................",
                "..KK........KK..",
                ".KBBK......KBBK.",
                ".KBDBK....KBDBK.",
                ".KBBBBKKKKBBBBK.",
                ".KBBBBBBBBBBBBK.",
                "KBBBBBBBBBBBBBBK",
                "KBBEWBBBBBBEWBBK",
                "KBBEEBLLLLBEEBBK",
                "KBBBBLLKKLLBBBBK",
                ".KBBBLKLLKLBBBK.",
                ".KBPBLLKKLLBPBK.",
                "..KBBBBBBBBBBK..",
                "..KBBLLLLLLBBK..",
                "..KBBKBBBBKBBK..",
                "...KK.KKKK.KK...",
            ],
            [7: "KBBBBBBBBBBBBBBK", 8: "KBBKKBLLLLBKKBBK"],
            [7: "KBBKKBBBBBBKKBBK", 8: "KBKBBKLLLLKBBKBK", 11: ".KBPBLKRRKLBPBK."]
        )
        case .bunny: (
            [
                "....KK....KK....",
                "...KBBK..KBBK...",
                "...KBPK..KPBK...",
                "...KBPK..KPBK...",
                "...KBBK..KBBK...",
                "..KBBBBKKBBBBK..",
                ".KBBBBBBBBBBBBK.",
                ".KBBBBBBBBBBBBK.",
                ".KBBEWBBBBEWBBK.",
                ".KBBEEBBBBEEBBK.",
                ".KBPBBBRRBBBPBK.",
                ".KBBBBKBBKBBBBK.",
                "..KBBBBKKBBBBK..",
                "..KBLLLLLLLLBK..",
                "..KBBKBBBBKBBK..",
                "...KK.KKKK.KK...",
            ],
            [8: ".KBBBBBBBBBBBBK.", 9: ".KBBKKBBBBKKBBK."],
            [8: ".KBBKKBBBBKKBBK.", 9: ".KBKBBKBBKBBKBK.", 11: ".KBBBBKRRKBBBBK."]
        )
        case .frog: (
            [
                "................",
                "..KKKK....KKKK..",
                ".KWWWWK..KWWWWK.",
                ".KWEWWK..KWEWWK.",
                ".KWEEWKKKKWEEWK.",
                ".KBWWBBBBBBWWBK.",
                "KBBBBBBBBBBBBBBK",
                "KBBBBBBBBBBBBBBK",
                "KBPPBBBBBBBBPPBK",
                "KBBKBBBBBBBBKBBK",
                "KBBBKKKKKKKKBBBK",
                ".KBBBBBBBBBBBBK.",
                ".KBBLLLLLLLLBBK.",
                "..KBLLLLLLLLBK..",
                ".KDDKBBBBBBKDDK.",
                ".KKK.KKKKKK.KKK.",
            ],
            [3: ".KWWWWK..KWWWWK.", 4: ".KEEEEKKKKEEEEK."],
            [9: "KBKBBBBBBBBBBKBK", 10: "KBBKKRRRRRRKKBBK"]
        )
        case .ghost: (
            [
                ".....KKKKKK.....",
                "...KKBBBBBBKK...",
                "..KBBBBBBBBBBK..",
                ".KBBBBBBBBBBBBK.",
                ".KBBBBBBBBBBBBK.",
                ".KBBEWBBBBEWBBK.",
                ".KBBEEBBBBEEBBK.",
                ".KBPBBBBBBBBPBK.",
                ".KBBBBKBBKBBBBK.",
                ".KBBBBBKKBBBBBK.",
                ".KBBBBBBBBBBBBK.",
                ".KBBBBBBBBBBBBK.",
                ".KBBBBBBBBBBBBK.",
                ".KBBBBBBBBBBBBK.",
                ".KBBK.KBBK.KBBK.",
                "..KK...KK...KK..",
            ],
            [5: ".KBBBBBBBBBBBBK."],
            [5: ".KBBKKBBBBKKBBK.", 6: ".KBKBBKBBKBBKBK.", 8: ".KBBBKBBBBKBBBK.", 9: ".KBBBBKRRKBBBBK."]
        )
        case .penguin: (
            [
                "................",
                ".....KKKKKK.....",
                "....KBBBBBBK....",
                "...KBBBBBBBBK...",
                "...KBWWBBWWBK...",
                "..KBWEWWWWEWBK..",
                "..KBWWWOOWWWBK..",
                "..KBWPWWWWPWBK..",
                ".KBBWWWWWWWWBBK.",
                ".KBWWWWWWWWWWBK.",
                "KBBWWWWWWWWWWBBK",
                "KBKWWWWWWWWWWKBK",
                ".K.KWWWWWWWWK.K.",
                "...KWWWWWWWWK...",
                "...KOOKKKKOOK...",
                "....KK....KK....",
            ],
            [5: "..KBKKWWWWKKBK.."],
            [4: "...KBWKBBKWBK...", 5: "..KBKWKWWKWKBK..", 6: "..KBWWWRRWWWBK.."]
        )
        case .axolotl: (
            [
                "................",
                "................",
                ".G............G.",
                "GKG..KKKKKK..GKG",
                ".GKGKBBBBBBKGKG.",
                "GKGKBBBBBBBBKGKG",
                ".GKBBBBBBBBBBKG.",
                "..KBEWBBBBEWBK..",
                "..KBEEBBBBEEBK..",
                "..KPBBKBBKBBPK..",
                "..KBBBBKKBBBBK..",
                "...KBLLLLLLBK...",
                "...KBLLLLLLBK...",
                "..KBBBBBBBBBBK..",
                "..KBK.KBBK.KBK..",
                "...K...KK...K...",
            ],
            [7: "..KBBBBBBBBBBK..", 8: "..KBKKBBBBKKBK.."],
            [7: "..KBKKBBBBKKBK..", 8: "..KKBBKBBKBBKK..", 9: "..KPBBKRRKBBPK.."]
        )
        case .dino: (
            [
                ".......KK.......",
                "......KDDK......",
                "....KKKBBKKK....",
                "...KBBBBBBBBK...",
                "..KBBBBBBBBBBK..",
                "..KBEWBBBBEWBK..",
                "..KBEEBBBBEEBK..",
                ".KDPBBBBBBBBPDK.",
                ".KBBBKBBBBKBBBK.",
                ".KBBBBKKKKBBBBK.",
                "..KBBBBBBBBBBK..",
                "..KBLLLLLLLLBK..",
                ".KBBLLLLLLLLBBK.",
                ".KBBLLLLLLLLBBK.",
                "..KBBK....KBBK..",
                "..KKKK....KKKK..",
            ],
            [5: "..KBBBBBBBBBBK..", 6: "..KBKKBBBBKKBK.."],
            [5: "..KBKKBBBBKKBK..", 6: "..KKBBKBBKBBKK..", 9: ".KBBBKRRRRKBBBK."]
        )
        }
    }
}

/// Draws one frame of a pet. Works in the app, widgets and Live Activities.
struct PixelPetView: View {
    var kind: PetKind
    var frame: Int = 0

    var body: some View {
        Canvas { context, size in
            let rows = kind.sprite(frame: frame)
            let count = CGFloat(rows.count)
            let px = min(size.width, size.height) / count
            let ox = (size.width - px * count) / 2
            let oy = (size.height - px * count) / 2
            for (y, row) in rows.enumerated() {
                for (x, code) in row.enumerated() {
                    guard let color = kind.pixelColor(code) else { continue }
                    let rect = CGRect(x: ox + CGFloat(x) * px, y: oy + CGFloat(y) * px, width: px + 0.4, height: px + 0.4)
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// Shared idle timing: a gentle bob, a blink every few seconds, and a happy wiggle every six.
enum PetMotion {
    static func isWiggling(_ t: TimeInterval) -> Bool { t.truncatingRemainder(dividingBy: 6) < 0.7 }
    static func idleFrame(_ t: TimeInterval) -> Int { t.truncatingRemainder(dividingBy: 3.4) < 0.18 ? 1 : 0 }
    static func wiggleHop(_ t: TimeInterval) -> Double { abs(sin(t * 9)) * 2 }
    static func bob(_ t: TimeInterval) -> Double { sin(t * 2.4) > 0 ? 1 : 0 }
}

/// In-app pet: idles with a gentle bob, blinks every few seconds, and hops happily when tapped.
struct AnimatedPet: View {
    var kind: PetKind
    @State private var cheerUntil = Date.distantPast

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let cheering = timeline.date < cheerUntil
            let wiggle = PetMotion.isWiggling(t)
            let frame = cheering || wiggle ? 2 : PetMotion.idleFrame(t)
            // Hop height in sprite pixels.
            let hop = cheering ? abs(sin(t * 9)) * 3 : (wiggle ? PetMotion.wiggleHop(t) : PetMotion.bob(t))
            GeometryReader { geo in
                let px = min(geo.size.width, geo.size.height) / 16
                PixelPetView(kind: kind, frame: frame)
                    .offset(y: -CGFloat(hop) * px)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { cheerUntil = .now.addingTimeInterval(1.6) }
    }
}
