import ActivityKit
import Foundation

struct PetProfile: Codable, Equatable {
    var pet: PetKind
    var name: String
    var birthDate: Date
    var accessory: Accessory? = nil

    var sign: ZodiacSign { ZodiacSign(birthDate: birthDate) }

    static let sample = PetProfile(
        pet: .cat,
        name: PetKind.cat.defaultName,
        birthDate: Calendar.current.date(from: DateComponents(year: 2000, month: 8, day: 1)) ?? .now
    )
}

/// The profile lives in the shared App Group so the widget can read it without the app running.
enum PetStore {
    /// Set from APP_BUNDLE_ID in project.yml via the AppGroupID Info.plist key.
    static let groupID = Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String ?? "group.com.matsavin.pixelpals"
    private static let key = "profile"

    static var defaults: UserDefaults { UserDefaults(suiteName: groupID) ?? .standard }

    static func load() -> PetProfile? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(PetProfile.self, from: data)
    }

    static func save(_ profile: PetProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: key)
    }

    static func loadCare() -> PetCare {
        guard let data = defaults.data(forKey: "care"),
              let care = try? JSONDecoder().decode(PetCare.self, from: data)
        else { return PetCare() }
        return care
    }

    static func saveCare(_ care: PetCare) {
        guard let data = try? JSONEncoder().encode(care) else { return }
        defaults.set(data, forKey: "care")
    }
}

struct PetAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var pet: PetKind
        var name: String
        var sign: ZodiacSign
        var message: String
        // Optional so activities started by older versions still decode.
        var mood: PetEmotion?
        /// Shown until the content goes stale a few seconds later, then the island falls back to `mood`
        /// by itself, with no extra update from the app.
        var reaction: PetEmotion?
        var food: Double?
        var fun: Double?
        var energy: Double?
        var accessory: Accessory?

        func emotion(isStale: Bool) -> PetEmotion {
            if let reaction, !isStale { return reaction }
            return mood ?? .content
        }
    }
}
