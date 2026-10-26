import Foundation

/// In-app language choice. Stored in the App Group so the widget and island follow it too.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system, en, ru

    var id: String { rawValue }

    /// Language names are shown in their own language, as iOS does.
    var title: String {
        switch self {
        case .system: String(localized: "System", bundle: .app)
        case .en: "English"
        case .ru: "Русский"
        }
    }

    static var current: AppLanguage {
        get { AppLanguage(rawValue: PetStore.defaults.string(forKey: "language") ?? "") ?? .system }
        set { PetStore.defaults.set(newValue.rawValue, forKey: "language") }
    }

    /// The localization actually used; "system" follows iOS (including Settings › Pixel Zodiac › Language).
    var code: String {
        self == .system ? (Bundle.main.preferredLocalizations.first ?? "en") : rawValue
    }
}

extension Bundle {
    /// The .lproj bundle for the chosen language; use with `String(localized:bundle:)`.
    static var app: Bundle {
        let code = AppLanguage.current.code
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path)
        else { return .main }
        return bundle
    }
}

extension Locale {
    /// Locale for SwiftUI text and date formatting in the chosen language.
    static var app: Locale {
        AppLanguage.current == .system ? .current : Locale(identifier: AppLanguage.current.code)
    }
}
