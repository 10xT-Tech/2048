//
//  GameStores.swift
//  2048 — App
//
//  `GameStoring` adapters. The session and statistics are small JSON blobs in UserDefaults
//  (on the device; not synced — no iCloud key-value store).
//

import Foundation
import Domain

struct UserDefaultsGameStore: GameStoring {
    private static let sessionKey = "game.session.v1"
    private static let statisticsKey = "game.statistics.v1"

    // UserDefaults is thread-safe; `.standard` is read at each call so the struct stays Sendable.
    private var defaults: UserDefaults { .standard }

    func loadSession() -> GameSession? {
        guard let data = defaults.data(forKey: Self.sessionKey) else { return nil }
        return try? JSONDecoder().decode(GameSession.self, from: data)
    }

    func saveSession(_ session: GameSession) {
        if let data = try? JSONEncoder().encode(session) { defaults.set(data, forKey: Self.sessionKey) }
    }

    func loadStatistics() -> Statistics {
        guard let data = defaults.data(forKey: Self.statisticsKey),
              let stats = try? JSONDecoder().decode(Statistics.self, from: data) else { return Statistics() }
        return stats
    }

    func saveStatistics(_ statistics: Statistics) {
        if let data = try? JSONEncoder().encode(statistics) { defaults.set(data, forKey: Self.statisticsKey) }
    }
}

/// Nothing persisted — UI tests start from the same seeded game every launch.
final class InMemoryGameStore: GameStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var session: GameSession?
    private var statistics = Statistics()

    func loadSession() -> GameSession? { lock.withLock { session } }
    func saveSession(_ session: GameSession) { lock.withLock { self.session = session } }
    func loadStatistics() -> Statistics { lock.withLock { statistics } }
    func saveStatistics(_ statistics: Statistics) { lock.withLock { self.statistics = statistics } }
}
