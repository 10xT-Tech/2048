//
//  Game2048App.swift
//  2048 — App
//
//  Composition root: the only place that knows the concrete adapters. Everything is local —
//  the game and statistics live in UserDefaults; there is no network code in the app.
//

import SwiftUI
import Domain
import Presentation

@main
struct Game2048App: App {
    @State private var language = LanguageStore()
    @State private var theme = ThemeStore()
    @State private var feedbackSettings: FeedbackSettings
    @State private var feedback: SoundAndHapticFeedback
    @State private var model: GameViewModel

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        // UI tests / screenshots: a fresh, deterministic game with nothing persisted.
        let isUITest = arguments.contains("-uiTestFreshGame")
        var store: GameStoring = isUITest ? InMemoryGameStore() : UserDefaultsGameStore()
        #if DEBUG
        // Screenshots / design review: every tile value on one board (nothing persisted).
        if arguments.contains("-demoBoard") {
            let demo = InMemoryGameStore()
            var session = GameSession(state: GameState(board: Board(rows: [
                [2, 4, 8, 16], [256, 128, 64, 32], [512, 1024, 2048, 4096], [0, 0, 2, 2],
            ]), score: 20_480, moves: 900))
            if !arguments.contains("-demoWin") { session.continueAfterWin() }
            demo.saveSession(session)
            store = demo
        }
        // A board with no moves left — the end panel and the summary.
        if arguments.contains("-demoOver") {
            let demo = InMemoryGameStore()
            demo.saveSession(GameSession(state: GameState(board: Board(rows: [
                [2, 4, 2, 4], [4, 8, 16, 8], [16, 32, 64, 32], [4, 128, 256, 512],
            ]),
                score: 3_480, moves: 260)))
            store = demo
        }
        #endif
        let rng: any RandomNumberGenerator = isUITest
            ? SeededGenerator(seed: 2048) : SystemRandomNumberGenerator()

        let settings = FeedbackSettings()
        let feedback = SoundAndHapticFeedback(settings: settings)
        _feedbackSettings = State(initialValue: settings)
        _feedback = State(initialValue: feedback)
        _model = State(initialValue: GameViewModel(store: store, feedback: feedback, rng: rng))
    }

    var body: some Scene {
        WindowGroup {
            RootView(model: model, language: language, theme: theme, feedback: feedbackSettings)
        }
    }
}
