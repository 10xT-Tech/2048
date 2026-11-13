//
//  StatisticsView.swift
//  2048 — Presentation
//
//  Lifetime numbers in a two-column grid of glass tiles, then the top games. Counted on the device.
//

import SwiftUI
import Domain
import DesignSystem

public struct StatisticsView: View {
    private let statistics: Statistics
    private let onClose: () -> Void

    public init(statistics: Statistics, onClose: @escaping () -> Void) {
        self.statistics = statistics
        self.onClose = onClose
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                VerticalScrollView {
                    VStack(alignment: .leading, spacing: Tokens.Space.s20) {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: Tokens.Space.s12),
                                            GridItem(.flexible(), spacing: Tokens.Space.s12)],
                                  spacing: Tokens.Space.s12) {
                            stat(Loc.t("Рекорд", "Best score"), statistics.bestScore.localized, id: "bestScore")
                            stat(Loc.t("Лучшая плитка", "Best tile"),
                                 statistics.bestTile > 0 ? "\(statistics.bestTile)" : "—", id: "bestTile")
                            stat(Loc.t("Сыграно игр", "Games played"), statistics.gamesPlayed.localized, id: "played")
                            stat(Loc.t("Собрано 2048", "Reached 2048"), statistics.gamesWon.localized, id: "won")
                            stat(Loc.t("Доля побед", "Win rate"), percent(statistics.winRate), id: "winRate")
                            stat(Loc.t("Средний счёт", "Average score"),
                                 statistics.averageScore?.localized ?? "—", id: "average")
                            stat(Loc.t("Всего ходов", "Total moves"), statistics.totalMoves.localized, id: "moves")
                            stat(Loc.t("Отмен хода", "Undos"), statistics.undos.localized, id: "undos")
                            stat(Loc.t("Время в игре", "Time played"),
                                 DurationText.format(statistics.totalPlayTime), id: "time")
                            stat(Loc.t("Средняя партия", "Average game"),
                                 statistics.averageDuration.map(DurationText.format) ?? "—", id: "avgTime")
                        }
                        TopGamesList(games: statistics.topGames)
                        Text(Loc.t("Средние значения и лучшие игры — по завершённым партиям. Статистика хранится только на этом iPhone.",
                                   "Averages and top games count finished games. Statistics stay on this iPhone only."))
                            .textStyle(Tokens.Text.footnote)
                            .foregroundStyle(Tokens.Content.tertiary)
                    }
                    .padding(Tokens.Space.s20)
                }
            }
            .navigationTitle(Loc.t("Статистика", "Statistics"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(Loc.t("Готово", "Done")) { onClose() }
                }
            }
        }
    }

    private func stat(_ title: String, _ value: String, id: String) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            Text(title.uppercased())
                .textStyle(Tokens.Text.caption2)
                .foregroundStyle(Tokens.Content.tertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .textStyle(Tokens.Text.title1)
                .monospacedDigit()
                .foregroundStyle(Tokens.Content.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.s16)
        .glassPanel(cornerRadius: Tokens.Radius.card)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("stats.\(id)")
    }

    private func percent(_ rate: Double?) -> String {
        guard let rate else { return "—" }
        return rate.formatted(.percent.precision(.fractionLength(0)).locale(Loc.locale))
    }
}

#Preview {
    var stats = Statistics()
    stats.gamesPlayed = 12
    stats.gamesWon = 3
    stats.bestScore = 20_480
    stats.bestTile = 2048
    stats.totalMoves = 4_210
    stats.finishedGames = 11
    stats.finishedScoreTotal = 88_000
    return StatisticsView(statistics: stats, onClose: {})
}
