//
//  BoardView.swift
//  2048 — Presentation
//
//  The square board: a glass card with a grid of empty cells, and the tiles on top, each positioned
//  by its cell and keyed by its id — so a slide is just a position change SwiftUI animates.
//  Entrances follow the original 2048: a spawned tile fades and grows in its own cell; a merged tile
//  pops (0 → 1.2 → 1) on top of the two source tiles, which stay under it until the next move.
//  The entrance scale is applied INSIDE `TileView`, before the cell offset — a scale on the offset
//  view would anchor at the board's top-left corner and the tile would fly in from there.
//

import SwiftUI
import Domain
import DesignSystem

struct BoardView: View {
    let size: Int
    let tiles: [Tile]
    var entrance: (Tile) -> TileEntrance = { _ in .appear }
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let gap = (side * GameTokens.gapRatio).rounded()
            let cell = (side - gap * CGFloat(size + 1)) / CGFloat(size)
            let radius = cell * GameTokens.tileRadiusRatio

            ZStack(alignment: .topLeading) {
                ForEach(0..<size * size, id: \.self) { index in
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(GameTokens.cell)
                        .frame(width: cell, height: cell)
                        .offset(offset(Position(row: index / size, col: index % size), cell: cell, gap: gap))
                }
                ForEach(tiles) { tile in
                    TileView(value: tile.value, side: cell, radius: radius, entrance: entrance(tile))
                        .offset(offset(tile.position, cell: cell, gap: gap))
                        .zIndex(Double(tile.id))
                        .transition(.identity)
                }
            }
            .frame(width: side, height: side, alignment: .topLeading)
            .glassPanel(cornerRadius: Tokens.Radius.card)
            .shadow(Tokens.Shadow.cardLight, Tokens.Shadow.cardDark, scheme: scheme)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Loc.t("Игровое поле", "Game board"))
        .accessibilityValue(accessibilityRows)
        .accessibilityIdentifier("game.board")
    }

    private func offset(_ position: Position, cell: CGFloat, gap: CGFloat) -> CGSize {
        CGSize(width: gap + CGFloat(position.col) * (cell + gap),
               height: gap + CGFloat(position.row) * (cell + gap))
    }

    /// Row by row, "empty" for a free cell — so VoiceOver can read the board.
    private var accessibilityRows: String {
        var grid = Array(repeating: Array(repeating: 0, count: size), count: size)
        for tile in tiles.sorted(by: { $0.id < $1.id }) where tile.position.row < size && tile.position.col < size {
            grid[tile.position.row][tile.position.col] = tile.value
        }
        let empty = Loc.t("пусто", "empty")
        return grid.enumerated().map { index, row in
            Loc.t("Ряд", "Row") + " \(index + 1): " + row.map { $0 == 0 ? empty : "\($0)" }.joined(separator: ", ")
        }.joined(separator: ". ")
    }
}

/// How a tile shows up when it is first put on the board.
public enum TileEntrance: Sendable {
    /// Spawned (or restored): grows from nothing in its cell.
    case appear
    /// Created by a merge: overshoots, then settles.
    case pop
}

struct TileView: View {
    let value: Int
    let side: CGFloat
    let radius: CGFloat
    let entrance: TileEntrance
    /// Both entrances start from nothing (as in the original). A merged tile is drawn over the two
    /// source tiles that slid under it, so the cell is never empty while it grows.
    @State private var scale: CGFloat
    @State private var opacity: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(value: Int, side: CGFloat, radius: CGFloat, entrance: TileEntrance = .appear) {
        self.value = value
        self.side = side
        self.radius = radius
        self.entrance = entrance
        _scale = State(initialValue: GameTokens.appearFromScale)
        _opacity = State(initialValue: entrance == .pop ? 1 : 0)
    }

    var body: some View {
        face
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear(perform: enter)
    }

    private func enter() {
        guard !reduceMotion else { scale = 1; opacity = 1; return }
        switch entrance {
        case .appear:
            withAnimation(GameTokens.appear) { scale = 1; opacity = 1 }
        case .pop:
            // The original's pop: 0 → 1.2 → 1.
            withAnimation(GameTokens.popUp) { scale = GameTokens.popPeakScale } completion: {
                withAnimation(GameTokens.popDown) { scale = 1 }
            }
        }
    }

    private var face: some View {
        let style = GameTokens.tile(value)
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return Text(verbatim: "\(value)")
            .font(.system(size: side * GameTokens.fontRatio(for: value), weight: .bold))
            .monospacedDigit()
            .tracking(-0.5)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(style.text)
            .padding(.horizontal, side * 0.06)
            .frame(width: side, height: side)
            .background(shape.fill(style.fill))
            .overlay {
                if style.hairline {
                    shape.strokeBorder(Tokens.Hairline.strong, lineWidth: Tokens.Hairline.width)
                }
            }
    }
}

#Preview {
    BoardView(size: 4, tiles: Board(rows: [
        [2, 4, 8, 16],
        [32, 64, 128, 256],
        [512, 1024, 2048, 4096],
        [0, 2, 0, 0],
    ]).tiles)
    .padding()
    .screenBackground()
}
