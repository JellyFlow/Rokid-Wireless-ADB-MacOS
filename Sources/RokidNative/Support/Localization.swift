import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case simplifiedChinese = "zh-Hans"
    case english = "en"

    var id: String { rawValue }

    var localizationCode: String {
        switch self {
        case .system:
            let preferred = Locale.preferredLanguages.first?.lowercased() ?? "en"
            return preferred.hasPrefix("zh") ? "zh-Hans" : "en"
        case .simplifiedChinese:
            return "zh-Hans"
        case .english:
            return "en"
        }
    }

    var locale: Locale { Locale(identifier: localizationCode) }
}

enum Localization {
    static func text(_ key: String, language: AppLanguage, bundle: Bundle = .main) -> String {
        guard language.localizationCode == "en",
              let path = bundle.path(forResource: "en", ofType: "lproj"),
              let localizedBundle = Bundle(path: path) else {
            return key
        }
        return localizedBundle.localizedString(forKey: key, value: key, table: nil)
    }
}
