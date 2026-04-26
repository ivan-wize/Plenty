//
//  DemoModeBanner.swift
//  Plenty
//
//  Target path: Plenty/Features/Home/DemoModeBanner.swift
//
//  A small amber banner displayed at the top of Home when the user is
//  exploring with seeded demo data. Tapping "Start fresh" hands off to
//  DemoModeService to clear everything and reset to an empty app state.
//
//  Banner only renders when DemoModeService.isActive is true. It is
//  cheap to keep in the view tree unconditionally; it returns
//  EmptyView when inactive.
//
//  Copy uses Plenty's calm voice (PRD §5):
//  "You're looking at demo data. Start fresh anytime."
//

import SwiftUI
import SwiftData

struct DemoModeBanner: View {

    @Environment(\.modelContext) private var modelContext

    /// Re-read on every view update so a clear from elsewhere reflects
    /// immediately. The flag is in shared UserDefaults; reads are cheap.
    private var isActive: Bool { DemoModeService.isActive }

    @State private var showingClearConfirm = false

    var body: some View {
        if isActive {
            banner
                .padding(.horizontal, 16)
                .confirmationDialog(
                    "Clear demo data?",
                    isPresented: $showingClearConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Clear and start fresh", role: .destructive) {
                        clearDemo()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Plenty will delete the demo accounts, transactions, and goals. This can't be undone.")
                }
        }
    }

    // MARK: - Banner

    private var banner: some View {
        HStack(spacing: 12) {
            Image(systemName: "wand.and.stars")
                .font(.body.weight(.medium))
                .foregroundStyle(Theme.amber)
                .symbolRenderingMode(.hierarchical)

            VStack(alignment: .leading, spacing: 2) {
                Text("You're exploring with demo data")
                    .font(Typography.Body.emphasis)
                    .foregroundStyle(.primary)
                Text("Start fresh anytime to clear it.")
                    .font(Typography.Support.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button {
                showingClearConfirm = true
            } label: {
                Text("Start fresh")
                    .font(Typography.Support.footnote.weight(.semibold))
                    .foregroundStyle(Theme.amber)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Theme.amber.opacity(Theme.Opacity.soft))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Start fresh, clear demo data")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.amber.opacity(Theme.Opacity.hairline))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .stroke(Theme.amber.opacity(Theme.Opacity.soft), lineWidth: 1)
                )
        )
    }

    // MARK: - Actions

    private func clearDemo() {
        DemoModeService.clearAll(modelContext: modelContext)
    }
}

// MARK: - Preview

#Preview {
    VStack {
        DemoModeBanner()
        Spacer()
    }
    .padding(.top, 24)
    .background(Theme.background)
}
