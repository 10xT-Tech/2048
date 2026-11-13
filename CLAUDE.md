# 10xMerge

Ships as **10xMerge** (display + product name; targets/modules stay `Game2048`, bundle id
`tech.10xt.game2048`, repo folder `2048`). The name must NOT contain "2048": it is a registered US trademark of
Ubisoft Mobile Games (Ketchapp, reg. 5075271, class 9) and taken on the App Store — "2048" may appear only
descriptively (subtitle/description: "a 2048-style puzzle"). About screen credits Gabriele Cirulli's original
(MIT); no code from it is used, only its animation timings (not copyrightable).

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
not a move (no spawn, no undo entry); spawn 2 (90%) / 4 (10%); 2048 wins (counted once; play goes on);
no empty cell and no equal neighbours → game over.
Reaching 2048 does NOT pause the game (no "keep going" step). The board's frame is LIVE: papaya orange (= the 8192 tile) as soon as
the score passes the record (the best score from before the game, `GameSession.bestAtStart`; the very first
game never counts) and while it keeps growing; otherwise green once 2048 is reached; otherwise, on game
over only, plain (inverted surface: black in light, white in dark). Game over never covers or moves the
board: Undo / New game stay above it, the panel "No more moves" (Undo move / Finish) appears UNDER it.
Finish (or New game mid-game) records the
game and opens the game summary (score, best tile, time, moves, top place, top-10 list).

## Design decisions
- **Tile colours** (user's call, revised): light tints from the design system's Signal hues, in pairs —
  2 neutral, 4 faint warm cream (hairline edge on both), 8/16 blue, 32/64 green, 128/256 amber, 512/1024 red; milestone tiles in
  full colour — 2048 green (`Signal.success`), 4096 red (`Signal.error`), 8192 McLaren papaya `#FF8000`;
  16384+ inverted (black / white). Coloured tiles stay mid-light in both themes (amber = sand, red = coral, never brown);
  numerals ink or white, whichever contrasts more (computed, `GameTokens.textHex`). Values from `tools/tile_tints.py` (OKLCH). Dark theme: empty
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
  on one board — 2048 is on it, so the green frame shows), `-demoOver` (no moves left; `-demoRecord` = as a new record); `-interfaceLanguage ru|en`; `-themePreference light|dark`.
- App icon: `swift tools/make_icon.swift` (thin white glyph on black, like Gist It's). The Orca project
  icon is the same picture, exported to `docs/orca-icon.png` (Orca keeps repo icons in its own store).

## TestFlight upload
App Store Connect record: **10xMerge**, bundle id `tech.10xt.game2048` (created 2026-11-13; build 1.0.0 (1) uploaded).
Uses the Apple ID signed in to Xcode (no API key on this machine).
```
xcodegen generate
xcodebuild archive -scheme Game2048 -configuration Release -destination 'generic/platform=iOS' \
  -archivePath ~/Library/Developer/Xcode/Archives/$(date +%Y-%m-%d)/10xMerge-<version>-<build>.xcarchive -allowProvisioningUpdates
xcodebuild -exportArchive -archivePath <that .xcarchive> -exportOptionsPlist tools/ExportOptions-TestFlight.plist \
  -exportPath <scratch dir outside Dropbox> -allowProvisioningUpdates
```
`CURRENT_PROJECT_VERSION` in project.yml is the NEXT build number to upload — bump it after every upload.
