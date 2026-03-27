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

    nonisolated static var selectableCases: [AppLanguage] {
        [.system] + allCases.filter { $0 != .system && L10n.hasTranslations(for: $0.rawValue) }
    }

    var displayName: String {
        switch self {
        case .system: return L10n.tr("Theo hệ thống")
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
    
    var flag: String {
        switch self {
        case .system: return "🌐"
        case .vietnamese: return "🇻🇳"
        case .english: return "🇺🇸"
        case .spanish: return "🇪🇸"
        case .french: return "🇫🇷"
        case .german: return "🇩🇪"
        case .portugueseBrazil: return "🇧🇷"
        case .russian: return "🇷🇺"
        case .chineseSimplified: return "🇨🇳"
        case .japanese: return "🇯🇵"
        case .korean: return "🇰🇷"
        case .hindi: return "🇮🇳"
        case .arabic: return "🇸🇦"
        }
    }
}

enum L10n {
    nonisolated static let languageStorageKey = "appLanguage"
    private nonisolated static let defaultFallbackLanguageCode = AppLanguage.english.rawValue
    private nonisolated static let developmentLanguageCode = AppLanguage.vietnamese.rawValue

    private final class BundleLocator {}

    nonisolated static var supportedAppLanguages: [AppLanguage] {
        AppLanguage.selectableCases
    }

    nonisolated static func currentLanguageCode() -> String {
        UserDefaults.standard.string(forKey: languageStorageKey) ?? AppLanguage.system.rawValue
    }

    nonisolated static func currentLocale() -> Locale {
        locale(for: currentLanguageCode())
    }

    nonisolated static func hasTranslations(for languageCode: String) -> Bool {
        let availableCodes = availableBundleLocalizationCodes()
        return preferredSupportedCode(for: languageCode, availableCodes: availableCodes) != nil
    }

    nonisolated static func resolvedLanguageCode(for languageCode: String) -> String {
        let selected = AppLanguage(rawValue: languageCode) ?? .system
        let availableCodes = availableTranslationCodes()

        if availableCodes.isEmpty {
            return selected == .system ? developmentLanguageCode : selected.rawValue
        }

        switch selected {
        case .system:
            let preferences = Locale.preferredLanguages.flatMap(languageCandidates(for:))
            if let preferred = Bundle.preferredLocalizations(from: availableCodes, forPreferences: preferences).first {
                return preferred
            }
        default:
            if let explicit = preferredSupportedCode(for: selected.rawValue, availableCodes: availableCodes) {
                return explicit
            }
        }

        if availableCodes.contains(defaultFallbackLanguageCode) {
            return defaultFallbackLanguageCode
        }

        if availableCodes.contains(developmentLanguageCode) {
            return developmentLanguageCode
        }

        return availableCodes.first ?? selected.rawValue
    }

    nonisolated static func locale(for languageCode: String) -> Locale {
        Locale(identifier: resolvedLanguageCode(for: languageCode))
    }

    /// Returns the Bundle for a specific language code.
    /// This loads the correct `.lproj` directory so NSLocalizedString picks the right translation.
    private static nonisolated func bundle(for languageCode: String) -> Bundle {
        let resolvedCode = resolvedLanguageCode(for: languageCode)
        let availableCodes = availableBundleLocalizationCodes()
        let supportedCode = preferredSupportedCode(for: resolvedCode, availableCodes: availableCodes) ?? resolvedCode

        for bundle in candidateBundles() {
            if let path = bundle.path(forResource: supportedCode, ofType: "lproj"),
               let localizedBundle = Bundle(path: path) {
                return localizedBundle
            }
        }

        // Fallback to main bundle
        return .main
    }

    nonisolated static func tr(_ key: String, languageCode: String) -> String {
        let code = resolvedLanguageCode(for: languageCode)

        // Look up in the target language bundle
        let targetBundle = bundle(for: code)
        let result = targetBundle.localizedString(forKey: key, value: nil, table: nil)

        // If we got a translation (not equal to key), use it
        if result != key {
            return result
        }

        // Fallback to English if target language didn't have it
        if code != defaultFallbackLanguageCode {
            let enBundle = bundle(for: defaultFallbackLanguageCode)
            let enResult = enBundle.localizedString(forKey: key, value: nil, table: nil)
            if enResult != key {
                return enResult
            }
        }
        
        // Fallback to Vietnamese (development language)
        if code != developmentLanguageCode {
            let viBundle = bundle(for: developmentLanguageCode)
            let viResult = viBundle.localizedString(forKey: key, value: nil, table: nil)
            if viResult != key {
                return viResult
            }
        }

        // Ultimate fallback: return the key itself
        return key
    }

    /// Convenience: reads the saved language from UserDefaults automatically.
    /// Use this in Services / Models where `appLanguage` is not available.
    nonisolated static func tr(_ key: String) -> String {
        tr(key, languageCode: currentLanguageCode())
    }

    nonisolated static func formatted(_ formatKey: String, languageCode: String? = nil, _ arguments: CVarArg...) -> String {
        let code = languageCode ?? currentLanguageCode()
        let format = tr(formatKey, languageCode: code)
        return String(format: format, locale: locale(for: code), arguments: arguments)
    }

    private static nonisolated func availableTranslationCodes() -> [String] {
        let availableCodes = availableBundleLocalizationCodes()

        return AppLanguage.allCases
            .filter { $0 != .system }
            .compactMap { language in
                preferredSupportedCode(for: language.rawValue, availableCodes: availableCodes) != nil
                    ? language.rawValue
                    : nil
            }
    }

    private static nonisolated func candidateBundles() -> [Bundle] {
        var seenPaths = Set<String>()
        return [Bundle.main, Bundle(for: BundleLocator.self)].filter { bundle in
            seenPaths.insert(bundle.bundlePath).inserted
        }
    }

    private static nonisolated func availableBundleLocalizationCodes() -> [String] {
        let rawCodes = Set(candidateBundles().flatMap { $0.localizations })
        let filtered = rawCodes.filter { $0.caseInsensitiveCompare("Base") != .orderedSame }
        return Array(filtered)
    }

    private static nonisolated func preferredSupportedCode(for languageCode: String, availableCodes: [String]) -> String? {
        let preferences = languageCandidates(for: languageCode)
        return Bundle.preferredLocalizations(from: availableCodes, forPreferences: preferences).first
    }

    private static nonisolated func languageCandidates(for languageCode: String) -> [String] {
        var candidates = [languageCode]
        let locale = Locale(identifier: languageCode)

        if let identifier = locale.language.languageCode?.identifier,
           !candidates.contains(identifier) {
            candidates.append(identifier)
        }

        return candidates
    }
}
