import Foundation

/// What the daily message is. Stored in the App Group so the widget, island and notifications follow it.
enum DailyContent: String, CaseIterable, Identifiable {
    case sign, quote, horoscope, mine, mix

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sign: String(localized: "Sign message", bundle: .app)
        case .quote: String(localized: "Quote", bundle: .app)
        case .horoscope: String(localized: "Horoscope", bundle: .app)
        case .mine: String(localized: "My messages", bundle: .app)
        case .mix: String(localized: "Mix", bundle: .app)
        }
    }

    static var current: DailyContent {
        get { DailyContent(rawValue: PetStore.defaults.string(forKey: "dailyContent") ?? "") ?? .sign }
        set { PetStore.defaults.set(newValue.rawValue, forKey: "dailyContent") }
    }

    /// Mix rotates sign message → quote → horoscope (→ your own messages, if any), one per day.
    func resolved(on date: Date) -> DailyContent {
        guard self == .mix else { return self }
        let rotation: [DailyContent] = CustomMessages.all.isEmpty ? [.sign, .quote, .horoscope] : [.sign, .quote, .horoscope, .mine]
        return rotation[dayNumber(date) % rotation.count]
    }
}

/// Messages the user writes themselves; they join the daily rotation.
enum CustomMessages {
    static var all: [String] {
        get { PetStore.defaults.stringArray(forKey: "customMessages") ?? [] }
        set { PetStore.defaults.set(newValue, forKey: "customMessages") }
    }

    static func message(on date: Date) -> String? {
        let all = all
        return all.isEmpty ? nil : all[dayNumber(date) % all.count]
    }
}

struct Quote: Decodable, Hashable {
    let text: String
    let author: String

    var formatted: String { "“\(text)” — \(author)" }
}

enum Quotes {
    private static var cache: [String: [Quote]] = [:]

    static var all: [Quote] {
        let code = AppLanguage.current.code
        if let cached = cache[code] { return cached }
        let loaded: [Quote] = loadJSON("quotes") ?? []
        cache[code] = loaded
        return loaded
    }

    static func quote(for profile: PetProfile, on date: Date) -> Quote? {
        let all = all
        guard !all.isEmpty else { return nil }
        let birthDay = Calendar.current.ordinality(of: .day, in: .year, for: profile.birthDate) ?? 0
        return all[(dayNumber(date) + birthDay * 7) % all.count]
    }
}

/// A light daily horoscope composed from forecast, advice and lucky color/number lists,
/// so each sign gets its own combination every day.
enum Horoscope {
    private struct Parts: Decodable {
        let forecasts: [String]
        let advice: [String]
        let colors: [String]
        let lucky: String
    }

    private static var cache: [String: Parts] = [:]

    private static var parts: Parts? {
        let code = AppLanguage.current.code
        if let cached = cache[code] { return cached }
        let loaded: Parts? = loadJSON("horoscope")
        cache[code] = loaded
        return loaded
    }

    static func text(for sign: ZodiacSign, on date: Date) -> String? {
        guard let parts, !parts.forecasts.isEmpty, !parts.advice.isEmpty, !parts.colors.isEmpty else { return nil }
        let day = dayNumber(date)
        let s = ZodiacSign.allCases.firstIndex(of: sign) ?? 0
        let forecast = parts.forecasts[(day * 7 + s * 5) % parts.forecasts.count]
        let advice = parts.advice[(day * 11 + s * 3 + 4) % parts.advice.count]
        let color = parts.colors[(day * 5 + s * 7) % parts.colors.count]
        let number = (day * 13 + s * 17) % 99 + 1
        return "\(forecast) \(advice)\n" + String(format: parts.lucky, color, String(number))
    }
}

private func dayNumber(_ date: Date) -> Int {
    Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
}

private func loadJSON<T: Decodable>(_ name: String) -> T? {
    guard let url = Bundle.app.url(forResource: name, withExtension: "json"),
          let data = try? Data(contentsOf: url)
    else { return nil }
    return try? JSONDecoder().decode(T.self, from: data)
}
