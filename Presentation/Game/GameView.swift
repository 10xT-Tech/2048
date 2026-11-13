//
//  GameView.swift
//  2048 — Presentation
//
//  The one game screen: the large title with Statistics + Settings in the toolbar (the same
//  `.inlineLarge` header as Gist It's main screens), the score and best, the board, then Undo and
//  New game. A swipe anywhere on the screen moves; arrow keys work too (hardware keyboard /
//  Simulator). On a win or game over the board stays fully visible and the choices appear as a
//  panel right under it (Keep going / Finish, Undo move / Finish); Finish opens the game summary.
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
                    Text(Loc.t("Соединяйте плитки — дойдите до 2048!", "Join the tiles, get to 2048!"))
                        .textStyle(Tokens.Text.subhead)
                        .foregroundStyle(Tokens.Content.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    board
                    if let end = model.endState {
                        EndPanel(kind: end, canUndo: model.canUndo, onKeepGoing: model.keepGoing,
                                 onUndo: model.undo, onFinish: model.finishGame)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    Spacer(minLength: 0)
                    if model.endState == nil {
                        controls
                    }
                }
                .padding(.horizontal, Tokens.Space.s20)
                .padding(.top, Tokens.Space.s8)
                .padding(.bottom, Tokens.Space.s16)
                .animation(Tokens.Motion.standard, value: model.endState)
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
            .navigationTitle("2048")
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
                  entrance: { [mergedIDs = model.mergedIDs] in mergedIDs.contains($0.id) ? .pop : .appear })
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

/// Win / game over: a glass panel under the board — the board itself stays visible.
private struct EndPanel: View {
    let kind: GameViewModel.EndState
    let canUndo: Bool
    let onKeepGoing: () -> Void
    let onUndo: () -> Void
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: Tokens.Space.s12) {
            HStack(spacing: Tokens.Space.s8) {
                Image(systemName: kind == .won ? "crown" : "square.grid.2x2")
                    .font(.system(size: 15, weight: .semibold))
                    .accessibilityHidden(true)
                Text(kind == .won ? Loc.t("Вы собрали 2048!", "You made 2048!")
                                  : Loc.t("Ходов больше нет", "No more moves"))
                    .textStyle(Tokens.Text.headline)
                    .accessibilityAddTraits(.isHeader)
            }
            .foregroundStyle(Tokens.Content.primary)
            HStack(spacing: Tokens.Space.s12) {
                switch kind {
                case .won:
                    EHButton(Loc.t("Закончить", "Finish"), icon: "flag.checkered", kind: .glass, fillWidth: true,
                             accessibilityID: "end.finish", action: onFinish)
                    EHButton(Loc.t("Играть дальше", "Keep going"), kind: .primary, fillWidth: true,
                             accessibilityID: "end.keepGoing", action: onKeepGoing)
                case .over:
                    if canUndo {
                        EHButton(Loc.t("Отменить ход", "Undo move"), icon: "arrow.uturn.backward", kind: .glass,
                                 fillWidth: true, accessibilityID: "end.undo", action: onUndo)
                    }
                    EHButton(Loc.t("Закончить", "Finish"), icon: "flag.checkered", kind: .primary, fillWidth: true,
                             accessibilityID: "end.finish", action: onFinish)
                }
            }
        }
        .padding(Tokens.Space.s16)
        .frame(maxWidth: .infinity)
        .glassPanel(cornerRadius: Tokens.Radius.card)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(kind == .won ? "end.won" : "end.over")
    }
}
