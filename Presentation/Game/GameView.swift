//
//  GameView.swift
//  2048 — Presentation
//
//  The one game screen: the large title with Statistics + Settings in the toolbar (the same
//  `.inlineLarge` header as Gist It's main screens), the score and best, Undo and New game, then the
//  board right under them — fixed in place. A swipe anywhere on the screen moves; arrow keys work too (hardware keyboard /
//  Simulator). The board's frame is live: orange once the score passes the record, else green once
//  2048 is reached (no pause), else plain on game over. On game over the board stays put and a panel
//  UNDER it offers Undo move / Finish; Finish opens the game summary.
//

import SwiftUI
import Domain
import DesignSystem

public struct GameView: View {
    @Bindable private var model: GameViewModel
    private let onShowStatistics: () -> Void
    private let onShowSettings: () -> Void
    @State private var confirmingNewGame = false
    @State private var swipeFired = false
    @FocusState private var focused: Bool

    public init(model: GameViewModel, onShowStatistics: @escaping () -> Void,
                onShowSettings: @escaping () -> Void) {
        self.model = model
        self.onShowStatistics = onShowStatistics
        self.onShowSettings = onShowSettings
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                VStack(spacing: Tokens.Space.s20) {
                    scores
                    controls
                    board
                    // The end message goes UNDER the board, into the free space — nothing above moves.
                    if model.isOver {
                        EndPanel(canUndo: model.canUndo, onUndo: model.undo, onFinish: model.finishGame)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Tokens.Space.s20)
                .padding(.top, Tokens.Space.s8)
                .padding(.bottom, Tokens.Space.s16)
                .animation(Tokens.Motion.standard, value: model.isOver)
            }
            .contentShape(Rectangle())
            .gesture(swipe)
            .focusable()
            .focusEffectDisabled()
            .focused($focused)
            .onKeyPress(keys: [.upArrow, .downArrow, .leftArrow, .rightArrow]) { press in
                switch press.key {
                case .upArrow: model.move(.up)
                case .downArrow: model.move(.down)
                case .leftArrow: model.move(.left)
                default: model.move(.right)
                }
                return .handled
            }
            .onAppear { focused = true }
            .navigationTitle("10xMerge")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onShowStatistics) { Image(systemName: "chart.bar") }
                        .accessibilityLabel(Loc.t("Статистика", "Statistics"))
                        .accessibilityIdentifier("toolbar.statistics")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onShowSettings) { Image(systemName: "gearshape") }
                        .accessibilityLabel(Loc.t("Настройки", "Settings"))
                        .accessibilityIdentifier("toolbar.settings")
                }
            }
            .sheet(isPresented: $confirmingNewGame) {
                ConfirmSheet(
                    icon: "arrow.counterclockwise",
                    title: Loc.t("Начать новую игру?", "Start a new game?"),
                    message: Loc.t("Текущая партия закончится. Счёт \(model.score.localized) останется в статистике.",
                                   "This game will end. Its score of \(model.score.localized) stays in your statistics."),
                    actions: [ConfirmAction(Loc.t("Новая игра", "New game"), accessibilityID: "confirm.newGame") {
                        model.newGame()
                    }]
                )
            }
            .sheet(item: $model.summary) { summary in
                GameSummaryView(summary: summary) { model.summary = nil }
            }
        }
    }

    // MARK: Parts

    private var scores: some View {
        HStack(spacing: Tokens.Space.s12) {
            ScoreBox(title: Loc.t("Счёт", "Score"), value: model.score, gain: model.lastGain,
                     accessibilityID: "game.score")
            ScoreBox(title: Loc.t("Рекорд", "Best"), value: model.bestScore, accessibilityID: "game.best")
        }
    }

    private var board: some View {
        BoardView(size: model.boardSize, tiles: model.tiles,
                  entrance: { [mergedIDs = model.mergedIDs] in mergedIDs.contains($0.id) ? .pop : .appear },
                  frameColor: frameColor)
    }

    private var frameColor: Color? {
        switch model.endHighlight {
        case .plain: GameTokens.endFramePlain
        case .won: GameTokens.endFrameWon
        case .record: GameTokens.endFrameRecord
        case nil: nil
        }
    }

    private var controls: some View {
        HStack(spacing: Tokens.Space.s12) {
            EHButton(Loc.t("Отменить", "Undo"), icon: "arrow.uturn.backward", kind: .glass,
                     fillWidth: true, accessibilityID: "game.undo") { model.undo() }
                .disabled(!model.canUndo)
            EHButton(Loc.t("Новая игра", "New game"), icon: "plus", kind: .primary,
                     fillWidth: true, accessibilityID: "game.newGame") {
                if model.newGameNeedsConfirmation { confirmingNewGame = true } else { model.newGame() }
            }
        }
    }

    /// A move fires as soon as the finger has travelled far enough — not on lift — one move per touch,
    /// so quick consecutive swipes feel immediate (like the Ketchapp 2048).
    private var swipe: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard !swipeFired else { return }
                let dx = value.translation.width
                let dy = value.translation.height
                guard max(abs(dx), abs(dy)) > 24 else { return }
                swipeFired = true
                if abs(dx) > abs(dy) {
                    model.move(dx > 0 ? .right : .left)
                } else {
                    model.move(dy > 0 ? .down : .up)
                }
            }
            .onEnded { _ in swipeFired = false }
    }
}

/// Game over: a glass panel under the board — the board stays where it is.
private struct EndPanel: View {
    let canUndo: Bool
    let onUndo: () -> Void
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: Tokens.Space.s12) {
            HStack(spacing: Tokens.Space.s8) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 15, weight: .semibold))
                    .accessibilityHidden(true)
                Text(Loc.t("Ходов больше нет", "No more moves"))
                    .textStyle(Tokens.Text.headline)
                    .accessibilityAddTraits(.isHeader)
            }
            .foregroundStyle(Tokens.Content.primary)
            HStack(spacing: Tokens.Space.s12) {
                if canUndo {
                    EHButton(Loc.t("Отменить ход", "Undo move"), icon: "arrow.uturn.backward", kind: .glass,
                             fillWidth: true, accessibilityID: "end.undo", action: onUndo)
                }
                EHButton(Loc.t("Закончить", "Finish"), icon: "flag.checkered", kind: .primary, fillWidth: true,
                         accessibilityID: "end.finish", action: onFinish)
            }
        }
        .padding(Tokens.Space.s16)
        .frame(maxWidth: .infinity)
        .glassPanel(cornerRadius: Tokens.Radius.card)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("end.over")
    }
}
