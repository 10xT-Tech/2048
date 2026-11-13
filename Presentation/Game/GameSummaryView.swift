//
//  GameSummaryView.swift
//  2048 — Presentation
//
//  Shown when a game finishes: its score, best tile, moves, time from the first move to the last,
//  its place among the best games (a new record called out), and the top games with this one
//  highlighted. A new game is already waiting behind it.
//

import SwiftUI
import Domain
import DesignSystem

struct GameSummaryView: View {
    let summary: GameViewModel.GameSummary
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                VerticalScrollView {
                    VStack(spacing: Tokens.Space.s20) {
                        header
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: Tokens.Space.s12),
                                            GridItem(.flexible(), spacing: Tokens.Space.s12)],
                                  spacing: Tokens.Space.s12) {
                            stat(Loc.t("Лучшая плитка", "Best tile"), "\(summary.record.bestTile)", id: "tile")
                            stat(Loc.t("Время", "Time"), DurationText.format(summary.record.duration), id: "time")
                            stat(Loc.t("Ходов", "Moves"), summary.record.moves.localized, id: "moves")
                            stat(Loc.t("Место в топе", "Top place"),
                                 summary.rank.map { "#\($0)" } ?? "—", id: "rank")
                        }
                        TopGamesList(games: summary.topGames, highlighted: summary.record.id)
                        EHButton(Loc.t("Новая игра", "New game"), icon: "plus", kind: .primary, fillWidth: true,
                                 accessibilityID: "summary.newGame", action: onClose)
                    }
                    .padding(Tokens.Space.s20)
                }
            }
            .navigationTitle(Loc.t("Итоги партии", "Game summary"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(Loc.t("Готово", "Done"), action: onClose)
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: Tokens.Space.s8) {
            Image(systemName: summary.record.won ? "crown" : "flag.checkered")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(Tokens.Content.primary)
                .frame(width: 56, height: 56)
                .background(Tokens.Fill.default, in: Circle())
                .accessibilityHidden(true)
            Text(summary.record.score.localized)
                .font(.system(size: 48, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Tokens.Content.primary)
                .accessibilityIdentifier("summary.score")
            Text(subtitle)
                .textStyle(Tokens.Text.subhead)
                .foregroundStyle(Tokens.Content.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Tokens.Space.s8)
    }

    private var subtitle: String {
        if summary.isNewRecord { return Loc.t("Новый рекорд!", "New record!") }
        if summary.record.won { return Loc.t("Вы собрали 2048", "You made 2048") }
        return Loc.t("очков", "points")
    }

    private func stat(_ title: String, _ value: String, id: String) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            Text(title.uppercased())
                .textStyle(Tokens.Text.caption2)
                .foregroundStyle(Tokens.Content.tertiary)
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
        .accessibilityIdentifier("summary.\(id)")
    }
}
