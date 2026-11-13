# 2048

Classic 2048 for iPhone, in the same visual language as **Gist It** (`../englishhelper`). Fully
offline: no network code, no accounts, no analytics, no SPM packages, no entitlements. Game, undo
history, statistics and preferences live in UserDefaults on the device.

- iOS 26 · Swift 6 (strict concurrency) · SwiftUI · Xcode 27 · xcodegen · iPhone only, portrait.
- Interface languages: RU / EN (`Loc.t(ru, en)` inline at each call site; system default, switchable in Settings).

## Architecture — framework modules, dependency rule enforced by the compiler

```
Domain  ◄── Presentation ──► DesignSystem      (App depends on all; nothing depends on App)
```

- **Domain** (Foundation only) — `Board`/`Tile` value types, `GameEngine` (pure rules), `GameSession`
  (undo ≤ 20, win flow, statistics bookkeeping), `Statistics`, `GameStoring` port, `SeededGenerator`.
- **DesignSystem** — **verbatim copy of Gist It's DesignSystem** (Tokens + GlassPanel, GlassCard, EHButton,
  ConfirmSheet, SegmentedSelector, ScreenBackground, DoneChime, …). Only `Loc.swift` is adapted (RU/EN,
  no LocCatalog). Change visuals in englishhelper first, then copy here — never edit the copies alone.
  Game-only tokens (tile ramp, board metrics, motion) live in `Presentation/Game/GameTokens.swift`.
- **Presentation** — `GameViewModel` (@MainActor @Observable), `GameView`, `BoardView`, `ScoreBox`,
  `StatisticsView`, `SettingsView`, `RootView`; `GameFeedback` (sounds + haptics); preference stores.
- **App** — composition root (`Game2048App`), `UserDefaultsGameStore` / `InMemoryGameStore`, assets.

## Rules (classic 2048)
Slide all tiles; equal neighbours merge once per move, the pair nearest the wall first
(`[2,2,2,2]←` → `[4,4]`, `[2,2,2]←` → `[4,2]`); score += merged value; a move that changes nothing is
not a move (no spawn, no undo entry); spawn 2 (90%) / 4 (10%); 2048 wins (overlay → "Keep going");
no empty cell and no equal neighbours → game over. Win / game over never cover the board: a panel
appears UNDER it (Keep going / Finish; Undo move / Finish). Finish (or New game mid-game) records the
game and opens the game summary (score, best tile, time, moves, top place, top-10 list).

## Design decisions
- **Tile colours** (user's call, revised): light tints from the design system's Signal hues, in pairs —
  2 neutral, 4 faint warm cream (hairline edge on both), 8/16 blue, 32/64 green, 128/256 amber, 512/1024 red, 2048+ inverted
  (black / white). Coloured tiles stay mid-light in both themes (amber = sand, red = coral, never brown);
  text is ink or white per tile, ≥ 4.5:1. Values from `tools/tile_tints.py` (OKLCH). Dark theme: empty
  cells are sunken wells darker than the board. Tile corners: 8% of the cell (sharper, Ketchapp-like).
- **App icon**: the 2×2 tile glyph only, no lettering (`tools/make_icon.swift`).
- **Tile identity drives animation**: tiles keep their `id` through slides; a merge consumes both sources
  and creates a new tile. `GameViewModel` animates in two phases — slide (`MoveOutcome.slid`), then
  settle — exactly like the original (gabrielecirulli/2048): the merged tile pops 0 → 1.2 → 1 (200 ms) OVER the two source tiles, which stay under it until the next move (no empty frame); a spawn fades/grows 0 → 1 (200 ms). Slide: 120 ms ease-in-out (original 100 ms). A swipe mid-animation settles at once; input is never dropped.
- **Statistics**: a game counts as played on its first move; a win counts once per game even across
  Undo (`countedWin`); averages, time played and the top 10 (`Statistics.topGames`, `GameRecord`) are over
  finished games. A game's duration runs from its first move to its last. Fields added after 1.0 decode
  leniently (custom `Statistics.init(from:)`, optional session dates) — never break saved data.
- Numbers and dates are formatted with `Loc.locale` (the app's language), not the system locale.
- **Sounds** are system sounds (follow the silent switch, no audio session): merge tones
  `Presentation/Resources/merge0…10.caf` (pitch climbs with value; `tools/make_sounds.py`), win = shared
  `DoneChime`. Haptics: light tap per slide, rigid impact on merge (stronger for bigger tiles),
  success on 2048, warning on game over. Both toggles in Settings.
- **No pop-up dialogs** (same as Gist It): confirmations use `ConfirmSheet`.
- Swift 6.4 crashes compiling `inout any RandomNumberGenerator` into a generic — the view model wraps
  it in `AnyRandomGenerator`.

## Build / test
```
xcodegen generate
xcodebuild test -scheme Game2048 -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0'
xcodebuild test -scheme Game2048UITests -destination '…'          # XCUI smoke tests
```
- The repo is in Dropbox: **never** point `-derivedDataPath` inside it — Dropbox xattrs break codesign
  ("resource fork, Finder information, or similar detritus not allowed"). Use the default DerivedData.
- Launch arguments: `-uiTestFreshGame` (seeded game, in-memory store); DEBUG `-demoBoard` (every tile value
  on one board, `-demoWin` to show the win panel), `-demoOver` (no moves left); `-interfaceLanguage ru|en`; `-themePreference light|dark`.
- App icon: `swift tools/make_icon.swift` (thin white glyph on black, like Gist It's). The Orca project
  icon is the same picture, exported to `docs/orca-icon.png` (Orca keeps repo icons in its own store).
