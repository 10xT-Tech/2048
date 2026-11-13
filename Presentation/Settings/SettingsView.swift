//
//  SettingsView.swift
//  2048 — Presentation
//
//  Settings sheet, laid out like Gist It's: a column of glass cards with uppercase section titles —
//  interface language, appearance, sound & haptics, statistics reset, about.
//

import SwiftUI
import DesignSystem

public struct SettingsView: View {
    private let language: LanguageStore
    private let theme: ThemeStore
    private let feedback: FeedbackSettings
    private let onResetStatistics: () -> Void
    private let onClose: () -> Void
    @State private var confirmingReset = false

    public init(language: LanguageStore, theme: ThemeStore, feedback: FeedbackSettings,
                onResetStatistics: @escaping () -> Void, onClose: @escaping () -> Void) {
        self.language = language
        self.theme = theme
        self.feedback = feedback
        self.onResetStatistics = onResetStatistics
        self.onClose = onClose
    }

    public var body: some View {
        @Bindable var feedback = feedback
        NavigationStack {
            ZStack {
                ScreenBackground()
                VerticalScrollView {
                    VStack(spacing: Tokens.Space.s20) {
                        card(Loc.t("Язык интерфейса", "Interface language")) {
                            SegmentedSelector(AppLanguage.allCases, selected: language.language,
                                              label: \.title, accessibilityID: "settings.language") {
                                language.language = $0
                            }
                        }
                        card(Loc.t("Оформление", "Appearance")) {
                            SegmentedSelector(ThemePreference.allCases, selected: theme.preference,
                                              label: \.title, accessibilityID: "settings.theme") {
                                theme.preference = $0
                            }
                        }
                        card(Loc.t("Звук и вибрация", "Sound & haptics")) {
                            Toggle(Loc.t("Звуки", "Sounds"), isOn: $feedback.soundOn)
                                .accessibilityIdentifier("settings.sound")
                            Divider().overlay(Tokens.Hairline.default)
                            Toggle(Loc.t("Вибрация", "Haptics"), isOn: $feedback.hapticsOn)
                                .accessibilityIdentifier("settings.haptics")
                            Text(Loc.t("Звуки следуют переключателю «Без звука».",
                                       "Sounds follow the Ring/Silent switch."))
                                .textStyle(Tokens.Text.footnote)
                                .foregroundStyle(Tokens.Content.tertiary)
                        }
                        card(Loc.t("Статистика", "Statistics")) {
                            Button(role: .destructive) { confirmingReset = true } label: {
                                Text(Loc.t("Сбросить статистику", "Reset statistics"))
                                    .textStyle(Tokens.Text.body)
                                    .foregroundStyle(Tokens.Signal.error)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("settings.resetStats")
                        }
                        card(Loc.t("О приложении", "About")) {
                            infoRow(Loc.t("Версия", "Version"), Self.version)
                            Divider().overlay(Tokens.Hairline.default)
                            Text(Loc.t("Работает без интернета. Никаких аккаунтов, рекламы и облаков — всё хранится только на этом iPhone.",
                                       "Works offline. No accounts, no ads, no cloud — everything stays on this iPhone."))
                                .textStyle(Tokens.Text.footnote)
                                .foregroundStyle(Tokens.Content.tertiary)
                        }
                    }
                    .padding(Tokens.Space.s20)
                }
            }
            .tint(Tokens.Content.primary)
            .navigationTitle(Loc.t("Настройки", "Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(Loc.t("Готово", "Done")) { onClose() }
                }
            }
            .sheet(isPresented: $confirmingReset) {
                ConfirmSheet(
                    icon: "chart.bar",
                    title: Loc.t("Сбросить статистику?", "Reset statistics?"),
                    message: Loc.t("Рекорд, сыгранные игры и остальные цифры обнулятся. Текущая партия останется.",
                                   "Best score, games played and every other number go back to zero. The current game stays."),
                    actions: [ConfirmAction(Loc.t("Сбросить", "Reset"), role: .destructive,
                                            accessibilityID: "confirm.reset", perform: onResetStatistics)]
                )
            }
        }
    }

    private func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s12) {
            Text(title.uppercased())
                .textStyle(Tokens.Text.caption2)
                .foregroundStyle(Tokens.Content.tertiary)
            content()
        }
        .textStyle(Tokens.Text.body)
        .foregroundStyle(Tokens.Content.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.s16)
        .glassPanel(cornerRadius: Tokens.Radius.card)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).textStyle(Tokens.Text.body).foregroundStyle(Tokens.Content.secondary)
            Spacer()
            Text(value).textStyle(Tokens.Text.body).foregroundStyle(Tokens.Content.primary)
        }
    }

    private static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }
}
