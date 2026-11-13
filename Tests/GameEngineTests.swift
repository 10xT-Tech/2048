//
//  GameEngineTests.swift
//  2048 — the classic rules, move by move.
//

import Testing
@testable import Domain

struct GameEngineTests {

    private func slid(_ rows: [[Int]], _ direction: Direction) -> [[Int]]? {
        GameEngine.slide(Board(rows: rows), direction)?.board.rows
    }

    @Test func slidesLeftWithoutMerging() {
        #expect(slid([[0, 2, 0, 4], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]], .left)?[0] == [2, 4, 0, 0])
    }

    @Test func mergesAPair() {
        #expect(slid([[2, 2, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]], .left)?[0] == [4, 0, 0, 0])
    }

    @Test func fourEqualMakeTwoPairs() {
        #expect(slid([[2, 2, 2, 2], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]], .left)?[0] == [4, 4, 0, 0])
    }

    @Test func pairNearestTheWallMergesFirst() {
        #expect(slid([[2, 2, 2, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]], .left)?[0] == [4, 2, 0, 0])
        #expect(slid([[2, 2, 2, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]], .right)?[0] == [0, 0, 2, 4])
    }

    @Test func aTileMergesOnlyOncePerMove() {
        #expect(slid([[4, 4, 8, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]], .left)?[0] == [8, 8, 0, 0])
        #expect(slid([[2, 2, 4, 8], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]], .left)?[0] == [4, 4, 8, 0])
    }

    @Test func mergesAcrossGaps() {
        #expect(slid([[2, 0, 0, 2], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]], .right)?[0] == [0, 0, 0, 4])
    }

    @Test func verticalMoves() {
        let rows = [[2, 0, 0, 0], [2, 0, 0, 0], [4, 0, 0, 0], [0, 0, 0, 0]]
        #expect(slid(rows, .up)?.map { $0[0] } == [4, 4, 0, 0])
        #expect(slid(rows, .down)?.map { $0[0] } == [0, 0, 4, 4])
    }

    @Test func aMoveThatChangesNothingIsNil() {
        #expect(slid([[2, 4, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]], .left) == nil)
        var rng = SeededGenerator(seed: 1)
        let state = GameState(board: Board(rows: [[2, 4, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]))
        #expect(GameEngine.move(state, .left, using: &rng) == nil)
        #expect(GameEngine.move(state, .up, using: &rng) == nil)
    }

    @Test func scoreIsTheSumOfMergedValues() throws {
        var rng = SeededGenerator(seed: 1)
        let state = GameState(board: Board(rows: [[2, 2, 4, 4], [8, 8, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), score: 10)
        let outcome = try #require(GameEngine.move(state, .left, using: &rng))
        #expect(outcome.scoreGained == 4 + 8 + 16)
        #expect(outcome.state.score == 10 + 28)
        #expect(outcome.state.moves == 1)
    }

    @Test func aMoveSpawnsExactlyOneTwoOrFour() throws {
        var rng = SeededGenerator(seed: 7)
        let state = GameState(board: Board(rows: [[2, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]))
        let outcome = try #require(GameEngine.move(state, .right, using: &rng))
        let spawned = try #require(outcome.spawned)
        #expect([2, 4].contains(spawned.value))
        #expect(outcome.state.board.tiles.count == 2)
        #expect(spawned.position != Position(row: 0, col: 3))
    }

    @Test func newGameHasTwoTiles() {
        var rng = SeededGenerator(seed: 3)
        let state = GameEngine.newGame(using: &rng)
        #expect(state.board.tiles.count == 2)
        #expect(state.board.tiles.allSatisfy { [2, 4].contains($0.value) })
        #expect(state.score == 0)
    }

    @Test func spawnsAreMostlyTwos() {
        var rng = SeededGenerator(seed: 42)
        var fours = 0
        for _ in 0..<2000 {
            var board = Board(size: 4)
            if GameEngine.spawn(on: &board, using: &rng)?.value == 4 { fours += 1 }
        }
        #expect((120...280).contains(fours))   // ~10% of 2000
    }

    @Test func tileIdentityFollowsTheSlide() throws {
        let board = Board(rows: [[0, 0, 0, 2], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
        let id = try #require(board.tiles.first).id
        let result = try #require(GameEngine.slide(board, .left))
        #expect(result.board.tiles.first?.id == id)
        #expect(result.board.tiles.first?.position == Position(row: 0, col: 0))
    }

    @Test func mergeConsumesBothAndCreatesANewTile() throws {
        let board = Board(rows: [[2, 2, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
        let oldIDs = Set(board.tiles.map(\.id))
        let result = try #require(GameEngine.slide(board, .left))
        #expect(result.merged.count == 1)
        #expect(!oldIDs.contains(result.merged[0].id))
        // Both sources slide into the merge target for the animation.
        #expect(result.slid.count == 2)
        #expect(result.slid.allSatisfy { $0.position == Position(row: 0, col: 0) })
    }

    @Test func gameOverOnlyWithNoEmptyCellAndNoEqualNeighbours() {
        let stuck = Board(rows: [[2, 4, 2, 4], [4, 2, 4, 2], [2, 4, 2, 4], [4, 2, 4, 2]])
        #expect(!GameEngine.canMove(stuck))
        let verticalPair = Board(rows: [[2, 4, 2, 4], [4, 2, 4, 2], [2, 4, 2, 4], [2, 8, 16, 32]])
        #expect(GameEngine.canMove(verticalPair))
        let oneEmpty = Board(rows: [[2, 4, 2, 4], [4, 2, 4, 2], [2, 4, 2, 4], [4, 2, 4, 0]])
        #expect(GameEngine.canMove(oneEmpty))
    }

    @Test func reaching2048Wins() {
        #expect(GameState(board: Board(rows: [[2048, 0], [0, 0]])).hasWon)
        #expect(!GameState(board: Board(rows: [[1024, 1024], [0, 0]])).hasWon)
    }

    @Test func worksOnOtherSizes() {
        #expect(slid([[2, 2, 2, 2, 2]] + Array(repeating: [0, 0, 0, 0, 0], count: 4), .left)?[0] == [4, 4, 2, 0, 0])
    }

    @Test func sameSeedSameGame() {
        var a = SeededGenerator(seed: 99)
        var b = SeededGenerator(seed: 99)
        #expect(GameEngine.newGame(using: &a) == GameEngine.newGame(using: &b))
    }
}
