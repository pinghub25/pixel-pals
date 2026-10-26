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
        case "T": Color(red: 0.45, green: 0.75, blue: 1.0)
        // Accessories
        case "M": Color(red: 0.95, green: 0.35, blue: 0.6)
        case "Y": Color(red: 1.0, green: 0.82, blue: 0.2)
        case "V": Color(red: 0.35, green: 0.55, blue: 1.0)
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

    /// Frames: 0 idle, 1 blink, 2 happy, 3 sad.
    func sprite(frame: Int, accessory: Accessory? = nil) -> [String] {
        var rows = art.base
        let overrides = switch frame {
        case 1: art.blink
        case 2: art.happy
        default: [Int: String]()
        }
        for (index, row) in overrides { rows[index] = row }
        if frame == 3 { makeSad(&rows) }
        if let accessory { wear(accessory, on: &rows) }
        return rows
    }

    /// Top of the head (where hats sit) and the eyes (row, left pupil column, right pupil column).
    private var anchors: (headTop: Int, eyes: (row: Int, left: Int, right: Int)) {
        switch self {
        case .cat: (4, (7, 4, 10))
        case .dog: (4, (7, 3, 11))
        case .bunny: (5, (8, 4, 10))
        case .frog: (4, (3, 3, 11))
        case .ghost: (0, (5, 4, 10))
        case .penguin: (1, (4, 5, 10))
        case .axolotl: (3, (7, 4, 10))
        case .dino: (2, (5, 4, 10))
        }
    }

    private func wear(_ accessory: Accessory, on rows: inout [String]) {
        var grid = rows.map(Array.init)
        func stamp(_ sprite: [String], row: Int, col: Int) {
            for (dy, line) in sprite.enumerated() {
                for (dx, code) in line.enumerated() where code != "." {
                    let y = row + dy, x = col + dx
                    if (0..<16).contains(y) && (0..<16).contains(x) { grid[y][x] = code }
                }
            }
        }
        let a = anchors
        switch accessory {
        case .bow:
            stamp(["MM.MM", ".MRM.", "MM.MM"], row: max(0, a.headTop - 2), col: 10)
        case .partyHat:
            let hat = ["..W..", "..V..", ".VYV.", "VYVYV"]
            stamp(hat, row: max(0, a.headTop - hat.count + 1), col: 5)
        case .crown:
            let crown = ["Y.YY.Y", "YYYYYY", "YRYYRY"]
            stamp(crown, row: max(0, a.headTop - crown.count + 1), col: 5)
        case .sunglasses:
            let (row, left, right) = a.eyes
            for eye in [left, right] {
                stamp(["KKKK", "KKKK"], row: row, col: eye - 1)
                grid[row][eye] = "W"
            }
            for col in (left + 3)..<(right - 1) { grid[row][col] = "K" }
        }
        rows = grid.map { String($0) }
    }

    /// Where each pet's smile and eyes are, so the sad face can be derived from the smile.
    private var face: (top: Int, corners: [Int], bottom: Int, middle: [Int], tear: (row: Int, col: Int)) {
        switch self {
        case .cat: (9, [6, 9], 10, [7, 8], (9, 4))
        case .dog: (10, [6, 9], 11, [7, 8], (9, 3))
        case .bunny: (11, [6, 9], 12, [7, 8], (10, 4))
        case .frog: (9, [3, 12], 10, Array(4...11), (5, 2))
        case .ghost: (8, [6, 9], 9, [7, 8], (7, 4))
        case .penguin: (0, [], 0, [], (6, 5))
        case .axolotl: (9, [6, 9], 10, [7, 8], (9, 4))
        case .dino: (8, [5, 10], 9, Array(6...9), (7, 4))
        }
    }

    /// Flips the smile into a frown (corners drop, middle rises) and adds a tear.
    private func makeSad(_ rows: inout [String]) {
        var grid = rows.map(Array.init)
        let f = face
        func fill(_ row: Int, _ col: Int) -> Character {
            let left = grid[row][col - 1], right = grid[row][col + 1]
            return left != "K" ? left : right
        }
        if !f.corners.isEmpty {
            for col in f.corners { grid[f.top][col] = fill(f.top, col) }
            for col in f.middle { grid[f.bottom][col] = fill(f.bottom, col) }
            for col in f.middle { grid[f.top][col] = "K" }
            for col in f.corners { grid[f.bottom][col] = "K" }
        }
        grid[f.tear.row][f.tear.col] = "T"
        rows = grid.map { String($0) }
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
    var accessory: Accessory?

    var body: some View {
        Canvas { context, size in
            let rows = kind.sprite(frame: frame, accessory: accessory)
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

/// Unlocked with friendship hearts; worn in the app, the island and the widget.
enum Accessory: String, Codable, Hashable, CaseIterable, Identifiable {
    case bow, sunglasses, partyHat, crown

    var id: String { rawValue }

    /// Hearts needed to unlock.
    var hearts: Int {
        switch self {
        case .bow: 10
        case .sunglasses: 25
        case .partyHat: 50
        case .crown: 100
        }
    }

    var title: String {
        switch self {
        case .bow: String(localized: "Bow", bundle: .app)
        case .sunglasses: String(localized: "Sunglasses", bundle: .app)
        case .partyHat: String(localized: "Party hat", bundle: .app)
        case .crown: String(localized: "Crown", bundle: .app)
        }
    }
}
