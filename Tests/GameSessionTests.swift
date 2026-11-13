//
//  GameSessionTests.swift
//  2048 — undo, win flow, statistics bookkeeping, persistence round-trip.
//

import Foundation
import Testing
@testable import Domain

struct GameSessionTests {

    private func session(_ rows: [[Int]]) -> GameSession {
        GameSession(state: GameState(board: Board(rows: rows)))
    }

    @Test func undoRestoresTheBoardAndScore() throws {
        var rng = SeededGenerator(seed: 5)
        var stats = Statistics()
        var s = session([[2, 2, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
        let before = s.state
        _ = try #require(s.move(.left, stats: &stats, using: &rng))
        #expect(s.state.score == 4)
        #expect(s.canUndo)
        let undone = s.undo(stats: &stats)
        #expect(undone)
        #expect(s.state == before)
        #expect(!s.canUndo)
        #expect(stats.undos == 1)
    }

    @Test func undoIsLimited() {
        var rng = SeededGenerator(seed: 11)
        var stats = Statistics()
        var s = GameSession(state: GameEngine.newGame(using: &rng))
        var moved = 0
        var i = 0
        while moved < GameSession.undoLimit + 5 && i < 1000 {
            if s.move(Direction.allCases[i % 4], stats: &stats, using: &rng) != nil { moved += 1 }
            if s.isOver { break }
            i += 1
        }
        #expect(s.history.count <= GameSession.undoLimit)
    }

    @Test func aMoveThatChangesNothingDoesNotEnterHistory() {
        var rng = SeededGenerator(seed: 5)
        var stats = Statistics()
        var s = session([[2, 4, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
        let outcome = s.move(.left, stats: &stats, using: &rng)
        #expect(outcome == nil)
        #expect(!s.canUndo)
        #expect(stats.totalMoves == 0)
        #expect(stats.gamesPlayed == 0)
    }

    @Test func reaching2048CountsAWin() throws {
        var rng = SeededGenerator(seed: 5)
        var stats = Statistics()
        var s = session([[1024, 1024, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
        _ = try #require(s.move(.left, stats: &stats, using: &rng))
        #expect(s.state.hasWon)
        #expect(stats.gamesWon == 1)
    }

    @Test func undoingAWinDoesNotCountItTwice() throws {
        var rng = SeededGenerator(seed: 5)
        var stats = Statistics()
        var s = session([[1024, 1024, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
        _ = try #require(s.move(.left, stats: &stats, using: &rng))
        s.undo(stats: &stats)
        _ = try #require(s.move(.left, stats: &stats, using: &rng))
        #expect(stats.gamesWon == 1)
        #expect(stats.gamesPlayed == 1)
    }

    @Test func statisticsTrackBestsAndMoves() throws {
        var rng = SeededGenerator(seed: 5)
        var stats = Statistics()
        var s = session([[64, 64, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
        _ = try #require(s.move(.left, stats: &stats, using: &rng))
        #expect(stats.bestScore == 128)
        #expect(stats.bestTile == 128)
        #expect(stats.totalMoves == 1)
        #expect(stats.gamesPlayed == 1)
    }

    @Test func newGameFinishesAGameWithMovesOnly() throws {
        var rng = SeededGenerator(seed: 5)
        var stats = Statistics()
        var s = session([[2, 2, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
        s.startNew(stats: &stats, using: &rng)            // untouched game: not counted
        #expect(stats.finishedGames == 0)

        s = session([[2, 2, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
        _ = try #require(s.move(.left, stats: &stats, using: &rng))
        s.startNew(stats: &stats, using: &rng)
        #expect(stats.finishedGames == 1)
        #expect(stats.finishedScoreTotal == 4)
        #expect(stats.averageScore == 4)
        #expect(s.state.moves == 0)
        #expect(!s.canUndo)
        #expect(s.state.board.tiles.count == 2)
    }

    @Test func winRate() {
        var stats = Statistics()
        #expect(stats.winRate == nil)
        stats.gamesPlayed = 4
        stats.gamesWon = 1
        #expect(stats.winRate == 0.25)
    }

    @Test func sessionSurvivesEncoding() throws {
        var rng = SeededGenerator(seed: 8)
        var stats = Statistics()
        var s = GameSession(state: GameEngine.newGame(using: &rng))
        for direction in Direction.allCases { _ = s.move(direction, stats: &stats, using: &rng) }
        let data = try JSONEncoder().encode(s)
        let decoded = try JSONDecoder().decode(GameSession.self, from: data)
        #expect(decoded == s)
        // Ids keep increasing after a reload — no collisions with existing tiles.
        #expect(decoded.state.board.nextID == s.state.board.nextID)
    }

    @Test func durationRunsFromFirstToLastMove() throws {
        var rng = SeededGenerator(seed: 5)
        var stats = Statistics()
        var s = session([[2, 2, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
        let t0 = Date(timeIntervalSince1970: 1_000)
        _ = try #require(s.move(.left, stats: &stats, using: &rng, at: t0))
        _ = s.move(.right, stats: &stats, using: &rng, at: t0.addingTimeInterval(95))
        #expect(s.duration == 95)
        let finished = try #require(s.startNew(stats: &stats, using: &rng, at: t0.addingTimeInterval(500)))
        #expect(finished.record.duration == 95)
        #expect(finished.record.score == 4)
        #expect(finished.rank == 1)
        #expect(stats.totalPlayTime == 95)
        #expect(stats.longestGame == 95)
        #expect(stats.topGames.count == 1)
    }

    @Test func topGamesKeepTheBestTenHighestFirst() {
        var stats = Statistics()
        for score in [300, 100, 500, 200, 400, 50, 60, 70, 80, 90, 10] {
            stats.add(GameRecord(score: score, bestTile: 64, moves: 10, duration: 60, endedAt: Date(), won: false))
        }
        #expect(stats.topGames.map(\.score) == [500, 400, 300, 200, 100, 90, 80, 70, 60, 50])
        #expect(stats.finishedGames == 11)
        let rank = stats.add(GameRecord(score: 450, bestTile: 256, moves: 10, duration: 60, endedAt: Date(), won: false))
        #expect(rank == 2)
        #expect(stats.topGames.count == Statistics.topLimit)
        let missed = stats.add(GameRecord(score: 1, bestTile: 2, moves: 1, duration: 1, endedAt: Date(), won: false))
        #expect(missed == nil)
    }

    @Test func statisticsSavedBy1_0StillDecode() throws {
        let old = #"{"gamesPlayed":3,"gamesWon":1,"bestScore":900,"bestTile":128,"totalMoves":120,"undos":2,"finishedGames":2,"finishedScoreTotal":1500}"#
        let stats = try JSONDecoder().decode(Statistics.self, from: Data(old.utf8))
        #expect(stats.gamesPlayed == 3)
        #expect(stats.bestScore == 900)
        #expect(stats.topGames.isEmpty)
        #expect(stats.totalPlayTime == 0)
    }

    @Test func sessionSavedBy1_0StillDecodes() throws {
        var rng = SeededGenerator(seed: 2)
        let s = GameSession(state: GameEngine.newGame(using: &rng))
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(s)) as! [String: Any]
        json.removeValue(forKey: "startedAt")
        json.removeValue(forKey: "lastMoveAt")
        let decoded = try JSONDecoder().decode(GameSession.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(decoded.state == s.state)
        #expect(decoded.duration == 0)
    }
}
