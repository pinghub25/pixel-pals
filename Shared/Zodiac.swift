import Foundation

enum ZodiacSign: String, Codable, Hashable, CaseIterable {
    case aries, taurus, gemini, cancer, leo, virgo, libra, scorpio, sagittarius, capricorn, aquarius, pisces

    init(birthDate: Date) {
        let parts = Calendar.current.dateComponents([.month, .day], from: birthDate)
        let md = (parts.month ?? 1) * 100 + (parts.day ?? 1)
        switch md {
        case 321...419: self = .aries
        case 420...520: self = .taurus
        case 521...620: self = .gemini
        case 621...722: self = .cancer
        case 723...822: self = .leo
        case 823...922: self = .virgo
        case 923...1022: self = .libra
        case 1023...1121: self = .scorpio
        case 1122...1221: self = .sagittarius
        case 120...218: self = .aquarius
        case 219...320: self = .pisces
        default: self = .capricorn
        }
    }

    var name: String {
        switch self {
        case .aries: String(localized: "Aries", bundle: .app)
        case .taurus: String(localized: "Taurus", bundle: .app)
        case .gemini: String(localized: "Gemini", bundle: .app)
        case .cancer: String(localized: "Cancer", bundle: .app)
        case .leo: String(localized: "Leo", bundle: .app)
        case .virgo: String(localized: "Virgo", bundle: .app)
        case .libra: String(localized: "Libra", bundle: .app)
        case .scorpio: String(localized: "Scorpio", bundle: .app)
        case .sagittarius: String(localized: "Sagittarius", bundle: .app)
        case .capricorn: String(localized: "Capricorn", bundle: .app)
        case .aquarius: String(localized: "Aquarius", bundle: .app)
        case .pisces: String(localized: "Pisces", bundle: .app)
        }
    }

    /// Variation selector U+FE0E keeps the glyph as text instead of an emoji tile.
    var symbol: String {
        let glyph = switch self {
        case .aries: "♈"
        case .taurus: "♉"
        case .gemini: "♊"
        case .cancer: "♋"
        case .leo: "♌"
        case .virgo: "♍"
        case .libra: "♎"
        case .scorpio: "♏"
        case .sagittarius: "♐"
        case .capricorn: "♑"
        case .aquarius: "♒"
        case .pisces: "♓"
        }
        return glyph + "\u{FE0E}"
    }

    var element: String {
        switch self {
        case .aries, .leo, .sagittarius: String(localized: "Fire", bundle: .app)
        case .taurus, .virgo, .capricorn: String(localized: "Earth", bundle: .app)
        case .gemini, .libra, .aquarius: String(localized: "Air", bundle: .app)
        case .cancer, .scorpio, .pisces: String(localized: "Water", bundle: .app)
        }
    }

    /// Whole phrase, since languages like Russian can't build it from the element word.
    var elementSign: String {
        switch self {
        case .aries, .leo, .sagittarius: String(localized: "Fire sign", bundle: .app)
        case .taurus, .virgo, .capricorn: String(localized: "Earth sign", bundle: .app)
        case .gemini, .libra, .aquarius: String(localized: "Air sign", bundle: .app)
        case .cancer, .scorpio, .pisces: String(localized: "Water sign", bundle: .app)
        }
    }

    /// Date range formatted in the user's language, e.g. "Mar 21 – Apr 19" or "21 мар. – 19 апр.".
    var dates: String {
        let (start, end): ((Int, Int), (Int, Int)) = switch self {
        case .aries: ((3, 21), (4, 19))
        case .taurus: ((4, 20), (5, 20))
        case .gemini: ((5, 21), (6, 20))
        case .cancer: ((6, 21), (7, 22))
        case .leo: ((7, 23), (8, 22))
        case .virgo: ((8, 23), (9, 22))
        case .libra: ((9, 23), (10, 22))
        case .scorpio: ((10, 23), (11, 21))
        case .sagittarius: ((11, 22), (12, 21))
        case .capricorn: ((12, 22), (1, 19))
        case .aquarius: ((1, 20), (2, 18))
        case .pisces: ((2, 19), (3, 20))
        }
        let style = Date.FormatStyle().month(.abbreviated).day().locale(.app)
        func format(_ md: (Int, Int)) -> String {
            let date = Calendar.current.date(from: DateComponents(year: 2001, month: md.0, day: md.1)) ?? .now
            return date.formatted(style)
        }
        return "\(format(start)) – \(format(end))"
    }
}

/// Daily messages from the bundled motivations.json (20 per sign).
enum Motivation {
    /// Parsed motivations.json per language code, loaded on first use.
    private static var tables: [String: [String: [String]]] = [:]

    private static var table: [String: [String]] {
        let code = AppLanguage.current.code
        if let cached = tables[code] { return cached }
        guard let url = Bundle.app.url(forResource: "motivations", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [String]].self, from: data)
        else { return [:] }
        tables[code] = decoded
        return decoded
    }

    static func lines(for sign: ZodiacSign) -> [String] { table[sign.rawValue] ?? [] }

    /// Which line a profile gets on a date. Same all day; the birthday shifts the order so
    /// two people of one sign don't get the same line on the same day.
    static func index(for profile: PetProfile, on date: Date = .now) -> Int {
        let count = max(1, lines(for: profile.sign).count)
        let calendar = Calendar.current
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        let birthDay = calendar.ordinality(of: .day, in: .year, for: profile.birthDate) ?? 0
        return (day + birthDay) % count
    }

    /// The day's message in whichever form the user chose (sign message, quote, horoscope or mix).
    static func message(for profile: PetProfile, on date: Date = .now) -> String {
        switch DailyContent.current.resolved(on: date) {
        case .quote:
            if let quote = Quotes.quote(for: profile, on: date) { return quote.formatted }
        case .horoscope:
            if let horoscope = Horoscope.text(for: profile.sign, on: date) { return horoscope }
        case .mine:
            if let mine = CustomMessages.message(on: date) { return mine }
        case .sign, .mix:
            break
        }
        return signMessage(for: profile, on: date)
    }

    static func signMessage(for profile: PetProfile, on date: Date = .now) -> String {
        let lines = lines(for: profile.sign)
        guard !lines.isEmpty else {
            return String(localized: "You're doing better than you think.", bundle: .app)
        }
        return lines[index(for: profile, on: date)]
    }
}
