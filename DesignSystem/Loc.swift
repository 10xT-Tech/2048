//
//  Loc.swift
//  DesignSystem — adapted from Gist It (englishhelper/DesignSystem/Loc.swift): same resolver and
//  `DSLoc.t(ru, en)` call shape, trimmed to the two languages 2048 ships (no LocCatalog).
//
//  Russian + English are supplied inline at each call site (`t(ru, en)`).
//

import Foundation

/// Which interface language is in effect, resolved from the user's stored choice or the system.
public enum AppLocale {
    public static let storageKey = "interfaceLanguage"
    /// The interface languages the app ships, as ISO 639-1 codes.
    public static let supported = ["ru", "en"]

    /// First system-preferred language we support, else English. Used when the user hasn't chosen.
    public static func systemDefaultCode() -> String { cachedSystemDefault }

    private static let cachedSystemDefault: String = {
        for language in Locale.preferredLanguages {
            let code = String(language.prefix(2)).lowercased()
            if supported.contains(code) { return code }
        }
        return "en"
    }()

    /// The user's stored choice if it's one we support; otherwise the system default; otherwise English.
    public static func currentCode() -> String {
        if let stored = UserDefaults.standard.string(forKey: storageKey), supported.contains(stored) {
            return stored
        }
        return systemDefaultCode()
    }
}

public enum DSLoc {
    public static func t(_ ru: String, _ en: String) -> String {
        AppLocale.currentCode() == "ru" ? ru : en
    }
}
