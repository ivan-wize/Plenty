//
//  TheReadView.swift
//  Plenty
//
//  Target path: Plenty/Features/Home/TheRead/TheReadView.swift
//
//  Renders TheRead beneath the hero number. Calm typography, no
//  decoration, no badge, no icon. Hidden when kind == .silence so the
//  hero stands alone on quiet days.
//
//  Subtle fade-in when the Read first appears or changes. Respects
//  Reduce Motion.
//

import SwiftUI

struct TheReadView: View {

    let read: TheRead?
    let isLoading: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if isLoading && read == nil {
                placeholder
            } else if let read, read.shouldDisplay {
                Text(read.body)
                    .font(Typography.Body.regular)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)
                    .transition(reduceMotion ? .identity : .opacity)
                    .accessibilityLabel(read.body)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: read?.body)
    }

    // MARK: - Placeholder

    /// Skeleton shown on first load before the Read has been generated.
    /// Two muted lines that approximate where text will land.
    private var placeholder: some View {
        VStack(spacing: 6) {
            placeholderBar(width: 220)
            placeholderBar(width: 160)
        }
        .padding(.horizontal, 24)
    }

    private func placeholderBar(width: CGFloat) -> some View {
        Capsule()
            .fill(Color.secondary.opacity(Theme.Opacity.soft))
            .frame(width: width, height: 12)
    }
}

#Preview("With Read") {
    TheReadView(
        read: TheRead(
            kind: .billReminder,
            body: "Three bills are still unpaid this month, totaling $1,240.",
            generatedAt: .now,
            isAIGenerated: true
        ),
        isLoading: false
    )
    .padding()
    .background(Theme.background)
}

#Preview("Silence") {
    TheReadView(
        read: TheRead.silence,
        isLoading: false
    )
    .padding()
    .background(Theme.background)
}

#Preview("Loading") {
    TheReadView(
        read: nil,
        isLoading: true
    )
    .padding()
    .background(Theme.background)
}
