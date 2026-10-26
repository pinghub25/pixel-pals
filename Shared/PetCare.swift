import SwiftUI

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
    /// Pats give a heart at most every few seconds, so the crown can't be farmed by tapping.
    var lastPatHeart: Date?

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

    /// How the pet feels right now, from its levels.
    var emotion: PetEmotion {
        let levels = [food, fun, energy]
        let lowCount = levels.filter { $0 < Self.lowLevel }.count
        if lowCount >= 2 || (levels.min() ?? 1) < 0.1 { return .sad }
        switch need {
        case .food: return .hungry
        case .play: return .bored
        case .rest: return .sleepy
        case nil: return (levels.min() ?? 0) > 0.6 ? .happy : .content
        }
    }

    /// The next moment the emotion can change on its own (a level crossing 0.6 or the low mark).
    /// Used to schedule a single background refresh instead of polling.
    var nextEmotionChange: Date? {
        let rates = [(food, Self.drainPerHour.food), (fun, Self.drainPerHour.fun), (energy, Self.drainPerHour.energy)]
        let thresholds = [0.6, Self.lowLevel, 0.1]
        let hours = rates.flatMap { value, rate in
            thresholds.filter { value > $0 }.map { (value - $0) / rate }
        }
        return hours.min().map { updated.addingTimeInterval($0 * 3600 + 60) }
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
            if Date.now.timeIntervalSince(lastPatHeart ?? .distantPast) > 5 {
                love += 1
                lastPatHeart = .now
            }
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

/// Moods from care levels, plus short reactions to Feed, Play and pats.
enum PetEmotion: String, Codable, Hashable {
    case happy, content, hungry, bored, sleepy, sad
    case love, excited

    /// Sprite frame: 0 idle, 1 eyes closed, 2 big smile, 3 sad.
    var frame: Int {
        switch self {
        case .happy, .love, .excited: 2
        case .content, .hungry, .bored: 0
        case .sleepy: 1
        case .sad: 3
        }
    }

    var symbol: String {
        switch self {
        case .happy: "sparkles"
        case .content: "face.smiling"
        case .hungry: "fork.knife"
        case .bored: "soccerball"
        case .sleepy: "moon.zzz.fill"
        case .sad: "cloud.drizzle.fill"
        case .love: "heart.fill"
        case .excited: "star.fill"
        }
    }

    var color: Color {
        switch self {
        case .happy, .excited: .yellow
        case .content: .mint
        case .hungry: .orange
        case .bored: .blue
        case .sleepy: .purple
        case .sad: Color(red: 0.45, green: 0.75, blue: 1.0)
        case .love: .pink
        }
    }

    func line(name: String) -> String {
        switch self {
        case .happy: String(localized: "\(name) is feeling great", bundle: .app)
        case .content: String(localized: "\(name) is doing fine", bundle: .app)
        case .hungry: PetNeed.food.line(name: name)
        case .bored: PetNeed.play.line(name: name)
        case .sleepy: PetNeed.rest.line(name: name)
        case .sad: String(localized: "\(name) is sad", bundle: .app)
        case .love: String(localized: "\(name) loves you", bundle: .app)
        case .excited: String(localized: "\(name) is so excited", bundle: .app)
        }
    }
}

enum PetAction: Equatable {
    case feed, play, nap, pat

    /// What the island shows for a few seconds after this action.
    var reaction: PetEmotion {
        switch self {
        case .feed, .pat: .love
        case .play: .excited
        case .nap: .sleepy
        }
    }

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
