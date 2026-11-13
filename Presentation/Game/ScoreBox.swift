//
//  ScoreBox.swift
//  2048 — Presentation
//
//  A glass score tile: an uppercase caption over a tabular number that rolls when it changes,
//  with an optional "+N" that floats up and fades after a merge.
//

import SwiftUI
import DesignSystem

struct ScoreBox: View {
    let title: String
    let value: Int
    var gain: GameViewModel.ScoreGain? = nil
    var accessibilityID: String

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            Text(title.uppercased())
                .textStyle(Tokens.Text.caption2)
                .foregroundStyle(Tokens.Content.tertiary)
            Text("\(value)")
                .textStyle(Tokens.Text.title2)
                .monospacedDigit()
                .foregroundStyle(Tokens.Content.primary)
                .contentTransition(.numericText(value: Double(value)))
                .animation(Tokens.Motion.standard, value: value)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Tokens.Space.s16)
        .padding(.vertical, Tokens.Space.s12)
        .glassPanel(cornerRadius: Tokens.Radius.control + 4)
        .overlay(alignment: .topTrailing) {
            if let gain {
                FloatingGain(amount: gain.amount)
                    .id(gain.id)
                    .padding(.trailing, Tokens.Space.s12)
                    .padding(.top, Tokens.Space.s8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(value)")
        .accessibilityIdentifier(accessibilityID)
    }
}

private struct FloatingGain: View {
    let amount: Int
    @State private var risen = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text("+\(amount)")
            .textStyle(Tokens.Text.headline)
            .monospacedDigit()
            .foregroundStyle(Tokens.Content.secondary)
            .offset(y: risen && !reduceMotion ? -18 : 0)
            .opacity(risen ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 0.7)) { risen = true }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
