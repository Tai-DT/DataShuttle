import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case vietnamese = "vi"
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case portugueseBrazil = "pt-BR"
    case russian = "ru"
    case chineseSimplified = "zh-Hans"
    case japanese = "ja"
    case korean = "ko"
    case hindi = "hi"
    case arabic = "ar"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .vietnamese: return "Tiếng Việt"
        case .english: return "English"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .portugueseBrazil: return "Português (Brasil)"
        case .russian: return "Русский"
        case .chineseSimplified: return "简体中文"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .hindi: return "हिन्दी"
        case .arabic: return "العربية"
        }
    }
}

enum L10n {
    static let languageStorageKey = "appLanguage"

    static func locale(for languageCode: String) -> Locale {
        let selected = AppLanguage(rawValue: languageCode) ?? .system
        switch selected {
        case .system:
            return .autoupdatingCurrent
        default:
            return Locale(identifier: selected.rawValue)
        }
    }

    static func tr(_ key: String, languageCode: String) -> String {
        let selected = AppLanguage(rawValue: languageCode) ?? .system
        let code = selected == .system
            ? Locale.autoupdatingCurrent.language.languageCode?.identifier ?? "en"
            : selected.rawValue

        if #available(macOS 13.0, *) {
            let localized = String(
                localized: String.LocalizationValue(key),
                bundle: .main,
                locale: Locale(identifier: code)
            )

            if localized != key {
                return localized
            }

            // If the selected locale is missing a translation, use English as a friendly fallback.
            if code != "en" {
                let english = String(
                    localized: String.LocalizationValue(key),
                    bundle: .main,
                    locale: Locale(identifier: "en")
                )
                if english != key {
                    return english
                }
            }
        }

        // Fallback to base key if not found in String Catalog.
        return key
    }
}