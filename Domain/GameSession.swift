//
//  GameSession.swift
//  2048 — Domain
//
//  One game in progress plus what's around it: the undo history, when the game started, and the statistics bookkeeping. Codable — the whole
//  session is what's saved, so a relaunch resumes the game with its undo steps.
//  Fields added after 1.0 are optional so sessions saved by an older build still decode.
//

import Foundation

public struct GameSession: Hashable, Codable, Sendable {
    /// How many moves back Undo can go.
    public static let undoLimit = 20

    public private(set) var state: GameState
    /// Previous states, oldest first; at most `undoLimit`.
    public private(set) var history: [GameState]
    /// Statistics flags that must NOT roll back with Undo (a win or a start is counted once a game).
    public private(set) var countedStart: Bool
    public private(set) var countedWin: Bool
    /// The first move's time — the game's duration runs from here.
    public private(set) var startedAt: Date?
    /// The latest move's time — a finished game ends here.
    public private(set) var lastMoveAt: Date?
    /// The best score before this game began — beating it makes this game a new record.
    public private(set) var bestAtStart: Int?

    public init(state: GameState, bestAtStart: Int? = nil) {
        self.state = state
        self.bestAtStart = bestAtStart
        self.history = []
        self.countedStart = false
        self.countedWin = false
    }

    public var canUndo: Bool { !history.isEmpty }
    public var isOver: Bool { state.isOver }

    /// Plays a move and records it in `stats`. Nil if nothing moved.
    public mutating func move(_ direction: Direction, stats: inout Statistics,
                              using rng: inout some RandomNumberGenerator, at now: Date = Date()) -> MoveOutcome? {
        guard let outcome = GameEngine.move(state, direction, using: &rng) else { return nil }
        if startedAt == nil { startedAt = now }
        lastMoveAt = now
        history.append(state)
        if history.count > Self.undoLimit { history.removeFirst(history.count - Self.undoLimit) }
        state = outcome.state

        if !countedStart {
            countedStart = true
            stats.gamesPlayed += 1
        }
        stats.totalMoves += 1
        stats.bestScore = max(stats.bestScore, state.score)
        stats.bestTile = max(stats.bestTile, state.board.maxValue)
        if state.hasWon && !countedWin {
            countedWin = true
            stats.gamesWon += 1
        }
        return outcome
    }

    /// Takes the last move back. False when there's nothing to undo.
    @discardableResult
    public mutating func undo(stats: inout Statistics) -> Bool {
        guard let previous = history.popLast() else { return false }
        state = previous
        stats.undos += 1
        return true
    }

    /// From the first move to the last one.
    public var duration: TimeInterval {
        guard let startedAt, let lastMoveAt else { return 0 }
        return max(0, lastMoveAt.timeIntervalSince(startedAt))
    }

    /// The game as it stands, as a record for the statistics. Nil before the first move.
    public func record(endedAt: Date = Date()) -> GameRecord? {
        guard state.moves > 0 else { return nil }
        return GameRecord(score: state.score, bestTile: state.board.maxValue, moves: state.moves,
                          duration: duration, endedAt: lastMoveAt ?? endedAt, won: countedWin)
    }

    /// Ends this game: records it in `stats` (a game with no moves isn't recorded) and starts a fresh
    /// one. Returns the record and its place in the top games (nil when it didn't make the list).
    @discardableResult
    public mutating func startNew(stats: inout Statistics, size: Int = GameEngine.defaultSize,
                                  using rng: inout some RandomNumberGenerator,
                                  at now: Date = Date()) -> (record: GameRecord, rank: Int?)? {
        let finished = record(endedAt: now).map { ($0, stats.add($0)) }
        self = GameSession(state: GameEngine.newGame(size: size, using: &rng), bestAtStart: stats.bestScore)
        return finished
    }
}

/// One finished game.
public struct GameRecord: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let score: Int
    public let bestTile: Int
    public let moves: Int
    /// From the first move to the last, in seconds.
    public let duration: TimeInterval
    public let endedAt: Date
    /// 2048 was reached in this game.
    public let won: Bool

    public init(id: UUID = UUID(), score: Int, bestTile: Int, moves: Int, duration: TimeInterval,
                endedAt: Date, won: Bool) {
        self.id = id
        self.score = score
        self.bestTile = bestTile
        self.moves = moves
        self.duration = duration
        self.endedAt = endedAt
        self.won = won
    }
}

/// Lifetime numbers, kept on the device only. Decodes leniently: a key an older build didn't write
/// starts at zero instead of failing the whole decode (which would wipe the statistics).
public struct Statistics: Hashable, Codable, Sendable {
    /// How many best games are kept.
    public static let topLimit = 10

    /// Games in which at least one move was made.
    public var gamesPlayed = 0
    /// Games in which 2048 was reached.
    public var gamesWon = 0
    public var bestScore = 0
    public var bestTile = 0
    public var totalMoves = 0
    public var undos = 0
    /// Games that ended (finished, or replaced by a new game after at least one move) and their
    /// scores — the average is taken over these, so the game in progress doesn't drag it down.
    public var finishedGames = 0
    public var finishedScoreTotal = 0
    /// Time across finished games, first move to last.
    public var totalPlayTime: TimeInterval = 0
    public var longestGame: TimeInterval = 0
    /// The best finished games by score, highest first; at most `topLimit`.
    public var topGames: [GameRecord] = []

    public init() {}

    public var winRate: Double? {
        gamesPlayed > 0 ? Double(gamesWon) / Double(gamesPlayed) : nil
    }

    public var averageScore: Int? {
        finishedGames > 0 ? finishedScoreTotal / finishedGames : nil
    }

    public var averageDuration: TimeInterval? {
        finishedGames > 0 ? totalPlayTime / Double(finishedGames) : nil
    }

    /// Records a finished game. Returns its 1-based place in `topGames`, nil if it didn't make it.
    @discardableResult
    public mutating func add(_ game: GameRecord) -> Int? {
        finishedGames += 1
        finishedScoreTotal += game.score
        totalPlayTime += game.duration
        longestGame = max(longestGame, game.duration)
        bestScore = max(bestScore, game.score)
        bestTile = max(bestTile, game.bestTile)
        // Ties keep the earlier game ahead.
        let index = topGames.firstIndex { $0.score < game.score } ?? topGames.endIndex
        guard index < Self.topLimit else { return nil }
        topGames.insert(game, at: index)
        if topGames.count > Self.topLimit { topGames.removeLast(topGames.count - Self.topLimit) }
        return index + 1
    }

    private enum CodingKeys: String, CodingKey {
        case gamesPlayed, gamesWon, bestScore, bestTile, totalMoves, undos, finishedGames,
             finishedScoreTotal, totalPlayTime, longestGame, topGames
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        gamesPlayed = try c.decodeIfPresent(Int.self, forKey: .gamesPlayed) ?? 0
        gamesWon = try c.decodeIfPresent(Int.self, forKey: .gamesWon) ?? 0
        bestScore = try c.decodeIfPresent(Int.self, forKey: .bestScore) ?? 0
        bestTile = try c.decodeIfPresent(Int.self, forKey: .bestTile) ?? 0
        totalMoves = try c.decodeIfPresent(Int.self, forKey: .totalMoves) ?? 0
        undos = try c.decodeIfPresent(Int.self, forKey: .undos) ?? 0
        finishedGames = try c.decodeIfPresent(Int.self, forKey: .finishedGames) ?? 0
        finishedScoreTotal = try c.decodeIfPresent(Int.self, forKey: .finishedScoreTotal) ?? 0
        totalPlayTime = try c.decodeIfPresent(TimeInterval.self, forKey: .totalPlayTime) ?? 0
        longestGame = try c.decodeIfPresent(TimeInterval.self, forKey: .longestGame) ?? 0
        topGames = try c.decodeIfPresent([GameRecord].self, forKey: .topGames) ?? []
    }
}
