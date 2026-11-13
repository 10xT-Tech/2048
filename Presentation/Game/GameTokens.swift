//
//  GameTokens.swift
//  2048 — Presentation
//
//  The game's own visual tokens, built ON the shared `Tokens` (DesignSystem stays a verbatim copy of
//  Gist It's, so game-only values live here).
//
//  Tiles are told apart by a LIGHT tint from the design system's own hues (`Tokens.Signal`
//  blue → green → amber → red), in pairs: 2 neutral, 4 a faint warm cream, 8/16 blue, 32/64 green, 128/256 amber,
//  512/1024 red; 2048+ is the inverted surface (black in light, white in dark) — the one stark tile.
//  Within a pair the higher value is a step deeper. Coloured tiles stay in the mid-light band in both
//  themes so amber reads as sand and red as coral, never brown. Text is ink or white, whichever
//  contrasts more (≥ 4.5:1 on every tile). Values from `tools/tile_tints.py` (OKLCH).

import SwiftUI
import DesignSystem

enum GameTokens {

    struct TileStyle {
        let fill: Color
        let text: Color
        /// The two neutral tiles (2, 4) need an edge to separate them from an empty cell.
        let hairline: Bool
    }

    /// One step per doubling: 2, 4, 8 … 1024, 2048 (2048 and above share the last step).
    private static let lightRamp: [UInt32] = [
        0xFFFFFF, 0xF4E3D1, 0xD3E4FE, 0xBAD5FB, 0xB5D6B8, 0x9BC89F,
        0xE0B586, 0xD49F63, 0xDA8377, 0xC86458, 0x060607,
    ]
    private static let darkRamp: [UInt32] = [
        0x3A3A3C, 0x53483E, 0x3F4E63, 0x4A5F7D, 0x506B53, 0x5B7F5E,
        0xB79065, 0xCEA16F, 0xDE958A, 0xF5BAB1, 0xFFFFFF,
    ]
    /// Steps whose numerals are white (the rest use ink).
    private static let lightWhiteText: Set<Int> = [10]
    private static let darkWhiteText: Set<Int> = [0, 1, 2, 3, 4, 5]

    static func step(for value: Int) -> Int {
        guard value > 1 else { return 0 }
        let log = Int(log2(Double(value)))
        return min(max(log - 1, 0), lightRamp.count - 1)
    }

    static func tile(_ value: Int) -> TileStyle {
        let s = step(for: value)
        let fill = Color(light: Color(hex: lightRamp[s]), dark: Color(hex: darkRamp[s]))
        let ink = Color(hex: 0x060607)
        let text = Color(light: lightWhiteText.contains(s) ? .white : ink,
                         dark: darkWhiteText.contains(s) ? .white : ink)
        return TileStyle(fill: fill, text: text, hairline: s <= 1)
    }

    /// An empty cell. Light: the tonal fill. Dark: a SUNKEN well, darker than the glass board, so even
    /// the first (darkest) tile stands out above it.
    static let cell = Color(light: Color(hex: 0x0A0A0C, opacity: 0.055), dark: Color.black.opacity(0.45))
    /// Gap between cells as a share of the board side.
    static let gapRatio: CGFloat = 0.028
    /// Tile corner radius as a share of the cell side.
    static let tileRadiusRatio: CGFloat = 0.08

    /// Number size as a share of the cell side, by digit count.
    static func fontRatio(for value: Int) -> CGFloat {
        switch String(value).count {
        case 1: 0.48
        case 2: 0.44
        case 3: 0.37
        case 4: 0.30
        default: 0.24
        }
    }

    // Motion — the original 2048 (gabrielecirulli/2048, style/main.scss): tiles slide with ease-in-out
    // (there 100 ms; a touch slower here, 120 ms); when the slide ends, a new tile appears (scale 0 → 1 +
    // fade, 200 ms "ease") and a merged tile pops OVER the two tiles that slid under it
    // (scale 0 → 1.2 → 1, 200 ms "ease" per half) — the sources stay beneath until the next move, so the
    // new number grows over the old one with no empty frame.
    static let slideDuration: TimeInterval = 0.12
    static let slide = Animation.easeInOut(duration: slideDuration)
    /// CSS `ease`.
    private static func cssEase(_ duration: TimeInterval) -> Animation {
        .timingCurve(0.25, 0.10, 0.25, 1.00, duration: duration)
    }
    static let appearFromScale: CGFloat = 0
    static let appear = cssEase(0.20)
    static let popPeakScale: CGFloat = 1.2
    static let popUp = cssEase(0.10)
    static let popDown = cssEase(0.10)
}
