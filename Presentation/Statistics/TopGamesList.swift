//
//  TopGamesList.swift
//  2048 — Presentation
//
//  The best games by score, as a glass card of rows: place, score, best tile, moves, duration, date.
//  Used by the game summary (the just-finished game highlighted) and by Statistics.
//

import SwiftUI
import Domain
import DesignSystem

struct TopGamesList: View {
    let games: [GameRecord]
    var highlighted: UUID? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s12) {
            Text(Loc.t("Лучшие игры", "Top games").uppercased())
                .textStyle(Tokens.Text.caption2)
                .foregroundStyle(Tokens.Content.tertiary)
            if games.isEmpty {
                Text(Loc.t("Пока пусто — закончите первую партию.", "Nothing yet — finish your first game."))
                    .textStyle(Tokens.Text.subhead)
                    .foregroundStyle(Tokens.Content.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(games.enumerated()), id: \.element.id) { index, game in
                        if index > 0 { Divider().overlay(Tokens.Hairline.default) }
                        row(place: index + 1, game: game, isHighlighted: game.id == highlighted)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.s16)
        .glassPanel(cornerRadius: Tokens.Radius.card)
        .accessibilityIdentifier("topGames")
    }

    private func row(place: Int, game: GameRecord, isHighlighted: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s12) {
            Text(verbatim: "\(place)")
                .textStyle(Tokens.Text.headline)
                .monospacedDigit()
                .foregroundStyle(isHighlighted ? Tokens.Content.onInvert : Tokens.Content.secondary)
                .frame(width: 26, height: 26)
                .background {
                    if isHighlighted { Circle().fill(Tokens.Surface.invert) }
                }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Tokens.Space.s8) {
                    Text(game.score.localized)
                        .textStyle(Tokens.Text.headline)
                        .monospacedDigit()
                        .foregroundStyle(Tokens.Content.primary)
                    if game.won {
                        Image(systemName: "crown")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Tokens.Content.secondary)
                            .accessibilityLabel(Loc.t("Собрано 2048", "Reached 2048"))
                    }
                }
                Text(details(game))
                    .textStyle(Tokens.Text.footnote)
                    .monospacedDigit()
                    .foregroundStyle(Tokens.Content.tertiary)
            }
            Spacer(minLength: 0)
            Text(game.endedAt.formatted(.dateTime.day().month(.abbreviated).locale(Loc.locale)))
                .textStyle(Tokens.Text.footnote)
                .foregroundStyle(Tokens.Content.tertiary)
        }
        .padding(.vertical, Tokens.Space.s8)
        .accessibilityElement(children: .combine)
    }

    private func details(_ game: GameRecord) -> String {
        [
            Loc.t("плитка", "tile") + " \(game.bestTile)",
            Loc.t("ходов", "moves") + " \(game.moves)",
            DurationText.format(game.duration),
        ].joined(separator: " · ")
    }
}

enum DurationText {
    /// "4:07", "1:02:15" — a game's length.
    static func format(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}
