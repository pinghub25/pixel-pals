import Foundation

/// Tamagotchi-style needs. Each level is 0...1 and drains per hour, so the state
/// can be projected to any moment (the widget does this without the app running).
struct PetCare: Codable, Equatable {
    var food = 0.8
    var fun = 0.8
    var energy = 0.8
    var updated = Date.now
    var love = 0
    var streak = 0
    var lastVisitDay = 0

    static let lowLevel = 0.3
    private static let drainPerHour = (food: 0.04, fun: 0.05, energy: 0.03)

    func at(_ date: Date) -> PetCare {
        var care = self
        let hours = max(0, date.timeIntervalSince(updated) / 3600)
        care.food = max(0, food - hours * Self.drainPerHour.food)
        care.fun = max(0, fun - hours * Self.drainPerHour.fun)
        care.energy = max(0, energy - hours * Self.drainPerHour.energy)
        care.updated = date
        return care
    }

    /// The most urgent need, if any level is low.
    var need: PetNeed? {
        let levels: [(PetNeed, Double)] = [(.food, food), (.play, fun), (.rest, energy)]
        guard let lowest = levels.min(by: { $0.1 < $1.1 }), lowest.1 < Self.lowLevel else { return nil }
        return lowest.0
    }

    /// When the first level will drop below `lowLevel`, for the "needs care" notification.
    var nextNeed: (need: PetNeed, date: Date)? {
        let levels: [(PetNeed, Double, Double)] = [
            (.food, food, Self.drainPerHour.food),
            (.play, fun, Self.drainPerHour.fun),
            (.rest, energy, Self.drainPerHour.energy),
        ]
        return levels
            .filter { $0.1 > Self.lowLevel }
            .map { (need: $0.0, date: updated.addingTimeInterval(($0.1 - Self.lowLevel) / $0.2 * 3600)) }
            .min { $0.date < $1.date }
    }

    mutating func apply(_ action: PetAction) {
        switch action {
        case .feed:
            food = min(1, food + 0.35)
            love += 1
        case .play:
            fun = min(1, fun + 0.35)
            energy = max(0, energy - 0.1)
            food = max(0, food - 0.05)
            love += 2
        case .nap:
            energy = min(1, energy + 0.45)
        case .pat:
            fun = min(1, fun + 0.03)
            love += 1
        }
    }

    /// Counts consecutive days the app was opened.
    mutating func checkIn(on date: Date) {
        let today = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        if lastVisitDay == today { return }
        streak = lastVisitDay == today - 1 ? streak + 1 : 1
        lastVisitDay = today
    }
}

enum PetNeed: String, Codable {
    case food, play, rest

    var symbol: String {
        switch self {
        case .food: "fork.knife"
        case .play: "soccerball"
        case .rest: "moon.zzz.fill"
        }
    }

    func line(name: String) -> String {
        switch self {
        case .food: String(localized: "\(name) is hungry", bundle: .app)
        case .play: String(localized: "\(name) wants to play", bundle: .app)
        case .rest: String(localized: "\(name) is sleepy", bundle: .app)
        }
    }
}

enum PetAction: Equatable {
    case feed, play, nap, pat

    /// How long the in-app animation runs.
    var duration: TimeInterval {
        switch self {
        case .feed: 2.4
        case .play: 3.0
        case .nap: 4.0
        case .pat: 0
        }
    }
}
