//
//  RootView.swift
//  2048 — Presentation
//
//  Hosts the game screen and its two sheets (Statistics, Settings). The game is rebuilt on a language
//  change (`.id`) so every `Loc.t` re-reads; the sheets live OUTSIDE that subtree so switching the
//  language in Settings doesn't close the sheet.
//

import SwiftUI
import Domain
import DesignSystem

public struct RootView: View {
    private let model: GameViewModel
    private let language: LanguageStore
    private let theme: ThemeStore
    private let feedback: FeedbackSettings
    @State private var sheet: Sheet?

    enum Sheet: String, Identifiable {
        case statistics, settings
        var id: String { rawValue }
    }

    public init(model: GameViewModel, language: LanguageStore, theme: ThemeStore, feedback: FeedbackSettings) {
        self.model = model
        self.language = language
        self.theme = theme
        self.feedback = feedback
    }

    public var body: some View {
        GameView(model: model,
                 onShowStatistics: { sheet = .statistics },
                 onShowSettings: { sheet = .settings })
            .id(language.language)
            .sheet(item: $sheet) { sheet in
                switch sheet {
                case .statistics:
                    StatisticsView(statistics: model.statistics) { self.sheet = nil }
                case .settings:
                    SettingsView(language: language, theme: theme, feedback: feedback,
                                 onResetStatistics: model.resetStatistics) { self.sheet = nil }
                        .id(language.language)
                }
            }
            .tint(Tokens.Content.primary)
            .preferredColorScheme(theme.colorScheme)
            .environment(\.locale, language.locale)
    }
}
