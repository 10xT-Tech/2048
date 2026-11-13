//
//  GameEngine.swift
//  2048 — Domain
//
//  The classic 2048 rules, as pure functions over value types:
//   • a move slides every tile as far as it goes in the direction;
//   • two equal tiles that meet merge into one of double value, scoring that value;
//   • a tile merges at most once per move, and the pair nearest the wall merges first
//     ([2,2,2,2] ← gives [4,4], [2,2,2] ← gives [4,2]);
//   • a move that changes nothing is not a move — no spawn, no history entry;
//   • after a move one tile spawns in a random empty cell: 2 (90%) or 4 (10%);
//   • reaching 2048 wins (play may continue); no empty cell and no equal neighbours ends the game.
//
//  Randomness is injected (`inout some RandomNumberGenerator`) so tests are deterministic.
//

import Foundation

public struct GameState: Hashable, Codable, Sendable {
    public var board: Board
    public var score: Int
    /// Moves made in this game (an undo takes one back).
    public var moves: Int

    public init(board: Board, score: Int = 0, moves: Int = 0) {
        self.board = board
        self.score = score
        self.moves = moves
    }

    public var hasWon: Bool { board.maxValue >= GameEngine.winValue }
    public var isOver: Bool { !GameEngine.canMove(board) }
}

/// Everything the view needs to animate one move.
public struct MoveOutcome: Sendable {
    /// The state after the move, the merges and the spawn.
    public let state: GameState
    /// Every tile that was on the board before the move, at the cell it slid to. Tiles consumed by a
    /// merge sit on the merge target (they are gone from `state`).
    public let slid: [Tile]
    /// Tiles created by merges this move (also present in `state`).
    public let merged: [Tile]
    /// The tile spawned after the move (nil only when no cell was free — impossible after a real move).
    public let spawned: Tile?
    public let scoreGained: Int
}

public enum GameEngine {
    public static let defaultSize = 4
    public static let winValue = 2048
    /// Probability that a spawned tile is a 4 rather than a 2.
    public static let fourProbability = 0.1

    /// A fresh game: two spawned tiles.
    public static func newGame(size: Int = defaultSize, using rng: inout some RandomNumberGenerator) -> GameState {
        var board = Board(size: size)
        spawn(on: &board, using: &rng)
        spawn(on: &board, using: &rng)
        return GameState(board: board)
    }

    /// Plays `direction`. Returns nil if nothing would move (the state is unchanged then).
    public static func move(_ state: GameState, _ direction: Direction,
                            using rng: inout some RandomNumberGenerator) -> MoveOutcome? {
        guard let slide = slide(state.board, direction) else { return nil }
        var board = slide.board
        let spawned = spawn(on: &board, using: &rng)
        let next = GameState(board: board, score: state.score + slide.scoreGained, moves: state.moves + 1)
        return MoveOutcome(state: next, slid: slide.slid, merged: slide.merged,
                           spawned: spawned, scoreGained: slide.scoreGained)
    }

    /// True if any move would change the board.
    public static func canMove(_ board: Board) -> Bool {
        if !board.emptyPositions.isEmpty { return true }
        let rows = board.rows
        for r in 0..<board.size {
            for c in 0..<board.size {
                if c + 1 < board.size, rows[r][c] == rows[r][c + 1] { return true }
                if r + 1 < board.size, rows[r][c] == rows[r + 1][c] { return true }
            }
        }
        return false
    }

    // MARK: Slide (no spawn)

    struct SlideResult {
        let board: Board
        let slid: [Tile]
        let merged: [Tile]
        let scoreGained: Int
    }

    /// Slides and merges without spawning. Nil when nothing moves.
    static func slide(_ board: Board, _ direction: Direction) -> SlideResult? {
        var working = board
        var result: [Tile] = []
        var slid: [Tile] = []
        var merged: [Tile] = []
        var gained = 0
        var changed = false

        for line in lines(size: board.size, direction: direction) {
            // Tiles in this line, nearest the wall first.
            let lineTiles = line.compactMap { board[$0.row, $0.col] }
            var slot = 0
            var index = 0
            while index < lineTiles.count {
                let tile = lineTiles[index]
                let target = line[slot]
                if index + 1 < lineTiles.count, lineTiles[index + 1].value == tile.value {
                    let partner = lineTiles[index + 1]
                    let value = tile.value * 2
                    let newTile = working.makeTile(value: value, at: target)
                    result.append(newTile)
                    merged.append(newTile)
                    slid.append(tile.moved(to: target))
                    slid.append(partner.moved(to: target))
                    gained += value
                    changed = true
                    index += 2
                } else {
                    if tile.position != target { changed = true }
                    let moved = tile.moved(to: target)
                    result.append(moved)
                    slid.append(moved)
                    index += 1
                }
                slot += 1
            }
        }

        guard changed else { return nil }
        working.setTiles(result)
        return SlideResult(board: working, slid: slid, merged: merged, scoreGained: gained)
    }

    /// The board's lines for a direction, each ordered from the wall the tiles move toward.
    static func lines(size: Int, direction: Direction) -> [[Position]] {
        let indices = Array(0..<size)
        switch direction {
        case .left:  return indices.map { r in indices.map { Position(row: r, col: $0) } }
        case .right: return indices.map { r in indices.reversed().map { Position(row: r, col: $0) } }
        case .up:    return indices.map { c in indices.map { Position(row: $0, col: c) } }
        case .down:  return indices.map { c in indices.reversed().map { Position(row: $0, col: c) } }
        }
    }

    // MARK: Spawn

    @discardableResult
    static func spawn(on board: inout Board, using rng: inout some RandomNumberGenerator) -> Tile? {
        let empty = board.emptyPositions
        guard !empty.isEmpty else { return nil }
        let position = empty[Int.random(in: 0..<empty.count, using: &rng)]
        let value = Double.random(in: 0..<1, using: &rng) < fourProbability ? 4 : 2
        let tile = board.makeTile(value: value, at: position)
        board.setTiles(board.tiles + [tile])
        return tile
    }
}
