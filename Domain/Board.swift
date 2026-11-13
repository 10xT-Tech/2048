//
//  Board.swift
//  2048 — Domain
//
//  The value types of a game: a square board of numbered tiles. Every tile carries a stable `id`
//  that survives slides, so the view can animate a tile from its old cell to its new one. A merge
//  consumes both source tiles and creates a NEW tile (new id) — the view slides the sources into the
//  target cell, then swaps them for the merged tile with a pop.
//

import Foundation

public enum Direction: String, CaseIterable, Codable, Sendable {
    case up, down, left, right
}

public struct Position: Hashable, Codable, Sendable {
    public let row: Int
    public let col: Int

    public init(row: Int, col: Int) {
        self.row = row
        self.col = col
    }
}

public struct Tile: Identifiable, Hashable, Codable, Sendable {
    public let id: Int
    public let value: Int
    public let position: Position

    public init(id: Int, value: Int, position: Position) {
        self.id = id
        self.value = value
        self.position = position
    }

    func moved(to position: Position) -> Tile {
        Tile(id: id, value: value, position: position)
    }
}

public struct Board: Hashable, Codable, Sendable {
    public let size: Int
    public private(set) var tiles: [Tile]
    /// The id the next created tile gets (spawn or merge) — monotonically increasing per game.
    public private(set) var nextID: Int

    public init(size: Int, tiles: [Tile] = [], nextID: Int? = nil) {
        precondition(size >= 2, "A board needs at least 2×2 cells")
        self.size = size
        self.tiles = tiles
        self.nextID = nextID ?? ((tiles.map(\.id).max() ?? -1) + 1)
    }

    /// A board from rows of values (0 = empty) — handy in tests and previews.
    public init(rows: [[Int]]) {
        var tiles: [Tile] = []
        for (r, row) in rows.enumerated() {
            for (c, value) in row.enumerated() where value != 0 {
                tiles.append(Tile(id: tiles.count, value: value, position: Position(row: r, col: c)))
            }
        }
        self.init(size: rows.count, tiles: tiles)
    }

    public subscript(row: Int, col: Int) -> Tile? {
        tiles.first { $0.position.row == row && $0.position.col == col }
    }

    /// Values as rows (0 = empty).
    public var rows: [[Int]] {
        var grid = Array(repeating: Array(repeating: 0, count: size), count: size)
        for tile in tiles { grid[tile.position.row][tile.position.col] = tile.value }
        return grid
    }

    public var emptyPositions: [Position] {
        let occupied = Set(tiles.map(\.position))
        return (0..<size).flatMap { r in (0..<size).map { Position(row: r, col: $0) } }
            .filter { !occupied.contains($0) }
    }

    public var maxValue: Int { tiles.map(\.value).max() ?? 0 }

    mutating func makeTile(value: Int, at position: Position) -> Tile {
        let tile = Tile(id: nextID, value: value, position: position)
        nextID += 1
        return tile
    }

    mutating func setTiles(_ tiles: [Tile]) { self.tiles = tiles }
}
