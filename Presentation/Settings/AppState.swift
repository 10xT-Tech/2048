//
//  AppState.swift
//  2048 — Presentation
//
//  Small persisted preferences (UserDefaults, on the device): interface language, theme, sound,
//  haptics. Mirrors Gist It's stores so both apps behave the same in Settings.
//

import SwiftUI
import DesignSystem

/// Tiny runtime localizer. Forwards to the DesignSystem resolver so Presentation and DesignSystem share
/// one source of truth. Russian + English are inline at the call site.
public enum Loc {
    public static func t(_ ru: String, _ en: String) -> String { DSLoc.t(ru, en) }
    /// The interface language's locale — numbers and dates follow the app's language, not the system's.
    public static var locale: Locale { Locale(identifier: AppLocale.currentCode()) }
}

extension Int {
    /// Grouped for the interface language: "3 480" / "3,480".
    var localized: String { formatted(.number.locale(Loc.locale)) }
}

public enum AppLanguage: String, CaseIterable, Sendable {
    case ru, en

    public var title: String {
        switch self {
        case .ru: "Русский"
        case .en: "English"
        }
    }

    public static var effective: AppLanguage { AppLanguage(rawValue: AppLocale.currentCode()) ?? .en }
}

@MainActor @Observable
public final class LanguageStore {
    public var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: AppLocale.storageKey) }
    }
    /// Starts from the effective language; nothing is persisted until the user picks one.
    public init() { language = AppLanguage.effective }
    public var locale: Locale { Locale(identifier: language.rawValue) }
}

public enum ThemePreference: String, CaseIterable, Sendable {
    case system, light, dark

    public var title: String {
        switch self {
        case .system: Loc.t("Системная", "System")
        case .light: Loc.t("Светлая", "Light")
        case .dark: Loc.t("Тёмная", "Dark")
        }
    }
}

@MainActor @Observable
public final class ThemeStore {
    public var preference: ThemePreference {
        didSet { UserDefaults.standard.set(preference.rawValue, forKey: Self.key) }
    }
    private static let key = "themePreference"

    public init() {
        let raw = UserDefaults.standard.string(forKey: Self.key)
        preference = raw.flatMap(ThemePreference.init(rawValue:)) ?? .system
    }

    public var colorScheme: ColorScheme? {
        switch preference {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

@MainActor @Observable
public final class FeedbackSettings {
    public var soundOn: Bool {
        didSet { UserDefaults.standard.set(soundOn, forKey: Self.soundKey) }
    }
    public var hapticsOn: Bool {
        didSet { UserDefaults.standard.set(hapticsOn, forKey: Self.hapticsKey) }
    }
    private static let soundKey = "soundOn"
    private static let hapticsKey = "hapticsOn"

    public init(defaults: UserDefaults = .standard) {
        soundOn = defaults.object(forKey: Self.soundKey) as? Bool ?? true
        hapticsOn = defaults.object(forKey: Self.hapticsKey) as? Bool ?? true
    }
}
