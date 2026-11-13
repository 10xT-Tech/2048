//
//  GameViewModelTests.swift
//  2048 — the screen's logic with an in-memory store and a recording feedback player.
//

import Foundation
import Testing
@testable import Domain
@testable import Presentation

@MainActor
private final class RecordingFeedback: GameFeedbackPlaying {
    var events: [GameEvent] = []
    func play(_ event: GameEvent) { events.append(event) }
}

private final class MemoryStore: GameStoring, @unchecked Sendable {
    var session: GameSession?
    var statistics = Statistics()
    var saves = 0
    init(session: GameSession? = nil) { self.session = session }
    func loadSession() -> GameSession? { session }
    func saveSession(_ session: GameSession) { self.session = session; saves += 1 }
    func loadStatistics() -> Statistics { statistics }
    func saveStatistics(_ statistics: Statistics) { self.statistics = statistics }
}

@MainActor
struct GameViewModelTests {

    private func model(_ rows: [[Int]]? = nil, store: MemoryStore? = nil)
        -> (GameViewModel, MemoryStore, RecordingFeedback) {
        let store = store ?? MemoryStore(session: rows.map { GameSession(state: GameState(board: Board(rows: $0))) })
        let feedback = RecordingFeedback()
        let model = GameViewModel(store: store, feedback: feedback, rng: SeededGenerator(seed: 1), animates: false)
        return (model, store, feedback)
    }

    @Test func startsAFreshGameAndSavesIt() {
        let (model, store, _) = model()
        #expect(model.tiles.count == 2)
        #expect(store.session != nil)
    }

    @Test func resumesTheSavedGame() {
        let rows = [[2, 4, 8, 16], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]
        let (model, _, _) = model(rows)
        #expect(model.tiles.count == 4)
        #expect(model.session.state.board.rows == rows)
    }

    @Test func moveScoresSavesAndPlaysFeedback() {
        let (model, store, feedback) = model([[2, 2, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
        model.move(.left)
        #expect(model.score == 4)
        #expect(model.lastGain?.amount == 4)
        #expect(store.session?.state.score == 4)
        #expect(store.statistics.totalMoves == 1)
        #expect(feedback.events == [.merge(4)])
        #expect(model.tiles == model.session.state.board.tiles)
    }

    @Test func blockedMoveDoesNothing() {
        let (model, store, feedback) = model([[2, 4, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
        let saves = store.saves
        model.move(.left)
        #expect(feedback.events.isEmpty)
        #expect(store.saves == saves)
        #expect(!model.canUndo)
    }

    @Test func undoTakesTheMoveBack() {
        let (model, _, _) = model([[2, 2, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
        model.move(.left)
        model.undo()
        #expect(model.score == 0)
        #expect(model.session.state.board.rows[0] == [2, 2, 0, 0])
        #expect(model.statistics.undos == 1)
    }

    @Test func winOverlayBlocksMovesUntilKeepGoing() {
        let (model, _, feedback) = model([[1024, 1024, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
        model.move(.left)
        #expect(model.endState == .won)
        #expect(feedback.events.contains(.won))
        let board = model.session.state.board
        model.move(.right)
        #expect(model.session.state.board == board)
        model.keepGoing()
        #expect(model.endState == nil)
    }

    @Test func gameOverOverlay() {
        // One move left: merging the two 2s fills the board with no pairs.
        let (model, _, feedback) = model([[2, 2, 8, 16], [32, 64, 128, 256], [4, 8, 16, 32], [64, 128, 256, 512]])
        model.move(.right)
        // The spawned tile lands in the one free cell; whether it's stuck depends on the value.
        if model.session.isOver {
            #expect(model.endState == .over)
            #expect(feedback.events.last == .over)
        } else {
            #expect(model.endState == nil)
        }
    }

    @Test func newGameNeedsConfirmationOnlyMidGame() {
        let (model, _, _) = model([[2, 2, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
        #expect(!model.newGameNeedsConfirmation)
        model.move(.left)
        #expect(model.newGameNeedsConfirmation)
        model.newGame()
        #expect(model.score == 0)
        #expect(!model.newGameNeedsConfirmation)
        #expect(model.statistics.finishedGames == 1)
    }

    @Test func bestScoreFollowsTheCurrentGame() {
        let store = MemoryStore(session: GameSession(state: GameState(board: Board(rows: [[2, 2], [0, 0]]))))
        store.statistics.bestScore = 2
        let (model, _, _) = model(store: store)
        model.move(.left)
        #expect(model.bestScore == 4)
    }

    @Test func resetStatistics() {
        let (model, store, _) = model([[2, 2, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
        model.move(.left)
        model.resetStatistics()
        #expect(model.statistics == Statistics())
        #expect(store.statistics == Statistics())
        #expect(model.score == 4)   // the game itself stays
    }

    @Test func finishingAGameOpensItsSummary() {
        let (model, _, _) = model([[2, 2, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
        model.move(.left)
        model.finishGame()
        #expect(model.summary?.record.score == 4)
        #expect(model.summary?.rank == 1)
        #expect(model.summary?.isNewRecord == true)
        #expect(model.statistics.topGames.count == 1)
        #expect(model.score == 0)            // a new game is already waiting
    }

    @Test func untouchedGameHasNoSummary() {
        let (model, _, _) = model([[2, 4, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
        model.newGame()
        #expect(model.summary == nil)
        #expect(model.statistics.topGames.isEmpty)
    }
}
