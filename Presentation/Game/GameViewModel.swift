//
//  GameViewModel.swift
//  2048 — Presentation
//
//  Drives the game screen. A move animates in two phases:
//   1. slide — every tile glides to its new cell (tiles consumed by a merge glide into the target);
//   2. settle — the consumed pairs are swapped for the merged tiles (a pop) and the spawned tile
//      grows out of its cell (like the original 2048: new tiles only after the slide).
//  A new swipe during an animation settles the previous move at once, so input is never dropped.
//  The win / game-over end panel waits for the settle. The session and statistics are saved after
//  every change. Finishing a game (game over → Finish, or New game mid-game) records it and opens a
//  summary of it (`summary`), with the top games.
//

import SwiftUI
import Domain

@MainActor @Observable
public final class GameViewModel {

    /// The game just finished, for the summary sheet.
    public struct GameSummary: Identifiable, Equatable {
        public let record: GameRecord
        /// 1-based place in the top games; nil when it didn't make the list.
        public let rank: Int?
        /// It beat every earlier finished game.
        public let isNewRecord: Bool
        public let topGames: [GameRecord]
        public var id: UUID { record.id }
    }

    public private(set) var session: GameSession
    public private(set) var statistics: Statistics
    /// The tiles on screen — differs from `session.state.board.tiles` only during a slide.
    public private(set) var tiles: [Tile]
    /// Tiles created by the latest move's merges — they pop in; every other new tile grows in.
    public private(set) var mergedIDs: Set<Int> = []
    public private(set) var isAnimating = false
    /// The latest score gain, for the floating "+N" (a new id each move).
    public private(set) var lastGain: ScoreGain?
    /// Set when a game finishes; the view shows it and clears it on dismissal.
    public var summary: GameSummary?

    public struct ScoreGain: Equatable, Identifiable {
        public let id: Int
        public let amount: Int
    }

    private let store: GameStoring
    private weak var feedback: GameFeedbackPlaying?
    private var rng: AnyRandomGenerator
    private var settleTask: Task<Void, Never>?
    private var gainCounter = 0
    /// Whether 2048 was already on the board before the move being animated (for the win/over cue).
    private var pendingWasWon: Bool?
    /// Tiles consumed by the animated move's merges, at their merge cell. As in the original 2048 they
    /// stay on screen UNDER the merged tile (which pops over them) until the next move.
    private var pendingSources: [Tile] = []
    private let animates: Bool

    public init(store: GameStoring, feedback: GameFeedbackPlaying?,
                rng: any RandomNumberGenerator = SystemRandomNumberGenerator(), animates: Bool = true) {
        var rng = AnyRandomGenerator(rng)
        let statistics = store.loadStatistics()
        let session: GameSession
        if let saved = store.loadSession() {
            session = saved
        } else {
            session = GameSession(state: GameEngine.newGame(using: &rng), bestAtStart: statistics.bestScore)
            store.saveSession(session)
        }
        self.store = store
        self.feedback = feedback
        self.rng = rng
        self.animates = animates
        self.statistics = statistics
        self.session = session
        tiles = session.state.board.tiles
    }

    // MARK: Derived

    public var score: Int { session.state.score }
    public var bestScore: Int { max(statistics.bestScore, score) }
    public var boardSize: Int { session.state.board.size }
    public var canUndo: Bool { session.canUndo }
    /// No moves left (the board waits for Undo move / Finish) — shown once the board has settled.
    public var isOver: Bool { !isAnimating && session.isOver }

    /// The board's frame, live during play: orange as soon as the score passes the record (and on as it
    /// grows), else green once 2048 is reached, else — only when the game is over — plain; none otherwise.
    /// Reaching 2048 doesn't pause the game.
    public enum EndHighlight: Equatable { case plain, won, record }

    public var endHighlight: EndHighlight? {
        if isNewRecord { return .record }
        if session.state.hasWon { return .won }
        return isOver ? .plain : nil
    }

    /// This game beat the best score from before it started. The very first game doesn't count —
    /// there was nothing to beat. (Sessions saved before 1.1 compare with the best finished game.)
    public var isNewRecord: Bool {
        let previous = session.bestAtStart ?? statistics.topGames.first?.score ?? 0
        return previous > 0 && score > previous
    }

    /// Starting over loses something worth a question: a game with moves that isn't finished.
    public var newGameNeedsConfirmation: Bool { session.state.moves > 0 && !session.isOver }

    // MARK: Intents

    public func move(_ direction: Direction) {
        settleNow()
        let wasWon = session.state.hasWon
        guard let outcome = session.move(direction, stats: &statistics, using: &rng) else { return }
        persist()

        if outcome.scoreGained > 0 {
            gainCounter += 1
            lastGain = ScoreGain(id: gainCounter, amount: outcome.scoreGained)
        }

        if let top = outcome.merged.map(\.value).max() {
            feedback?.play(.merge(top))
        } else {
            feedback?.play(.slide)
        }

        guard animates else {
            mergedIDs = Set(outcome.merged.map(\.id))
            tiles = session.state.board.tiles
            announceEnd(wasWon: wasWon)
            return
        }
        isAnimating = true
        pendingWasWon = wasWon
        mergedIDs = Set(outcome.merged.map(\.id))
        let survivors = Set(session.state.board.tiles.map(\.id))
        pendingSources = outcome.slid.filter { !survivors.contains($0.id) }
        withAnimation(GameTokens.slide) { tiles = outcome.slid }
        settleTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(GameTokens.slideDuration))
            guard !Task.isCancelled, let self else { return }
            self.settle()
        }
    }

    public func undo() {
        settleNow()
        guard session.undo(stats: &statistics) else { return }
        lastGain = nil
        mergedIDs = []
        persist()
        withAnimation(animates ? GameTokens.slide : nil) { tiles = session.state.board.tiles }
    }

    /// Ends this game (recording it if it had moves — then its summary opens) and starts a new one.
    public func newGame() {
        settleNow()
        let previousTop = statistics.topGames.first?.score
        if let finished = session.startNew(stats: &statistics, using: &rng) {
            summary = GameSummary(record: finished.record, rank: finished.rank,
                                  isNewRecord: finished.rank == 1 && finished.record.score > (previousTop ?? 0),
                                  topGames: statistics.topGames)
        }
        lastGain = nil
        persist()
        mergedIDs = []
        tiles = session.state.board.tiles   // the new tiles grow in on their own (TileView)
    }

    /// "Finish" from the end panel: the same as starting a new game.
    public func finishGame() { newGame() }

    public func resetStatistics() {
        statistics = Statistics()
        store.saveStatistics(statistics)
    }

    // MARK: Private

    private func settle() {
        settleTask = nil
        // No surrounding animation: survivors are already in place and new tiles run their own entrance
        // (grow / pop) in TileView.
        // Sources first (lower ids → drawn below), then the board: merged tiles pop over the sources.
        tiles = pendingSources + session.state.board.tiles
        pendingSources = []
        isAnimating = false
        announcePending()
    }

    /// Finishes a running slide immediately (a new input arrived).
    private func settleNow() {
        guard let task = settleTask else { return }
        task.cancel()
        settleTask = nil
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            tiles = session.state.board.tiles
            isAnimating = false
        }
        pendingSources = []
        announcePending()
    }

    private func announcePending() {
        guard let wasWon = pendingWasWon else { return }
        pendingWasWon = nil
        announceEnd(wasWon: wasWon)
    }

    private func announceEnd(wasWon: Bool) {
        if session.state.hasWon && !wasWon {
            feedback?.play(.won)
        } else if session.isOver {
            feedback?.play(.over)
        }
    }

    private func persist() {
        store.saveSession(session)
        store.saveStatistics(statistics)
    }
}

/// A concrete wrapper, so the generator can be passed `inout` to the engine's generic functions
/// (opening an `inout any RandomNumberGenerator` there crashes the Swift 6.4 compiler).
struct AnyRandomGenerator: RandomNumberGenerator {
    private var base: any RandomNumberGenerator
    init(_ base: any RandomNumberGenerator) { self.base = base }
    mutating func next() -> UInt64 { base.next() }
}
