//
//  OverviewEmptyHero.swift
//  Plenty
//
//  Target path: Plenty/Features/Overview/OverviewEmptyHero.swift
//
//  Phase 1.1 (post-launch v1): the calm empty state shown on Overview
//  before the user has added any accounts, transactions, income
//  sources, or savings goals. Replaces the hero number, the
//  projection line, and The Read while empty.
//
//  Design intent: showing "$0" in sage on a brand-new install reads
//  as "you have plenty" — the opposite of the truth. We suppress the
//  number entirely and invite the user to give Plenty enough to
//  compute against.
//
//  Two affordances rather than a single Menu:
//
//    • Primary "Add income" — leads because the budget formula
//      begins with money in (confirmedIncome − bills − expenses).
//      A first-time user who sets up their paycheck immediately
//      sees a real number on next render.
//
//    • Secondary "Or add a bill" — for the user who lands here
//      right after paying rent and wants to record that first.
//
//  The primary action is always reachable in two taps via the FAB
//  too; this view exists to make the *first* tap unambiguous.
//

import SwiftUI

struct OverviewEmptyHero: View {

    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 20) {
            mark

            VStack(spacing: 8) {
                Text("Welcome to Plenty")
                    .font(Typography.Title.medium)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text("Add your first paycheck or bill, and your number will appear here.")
                    .font(Typography.Body.regular)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 4) {
                primaryButton
                secondaryButton
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Mark

    private var mark: some View {
        Image(systemName: "leaf")
            .font(.system(size: 48, weight: .light))
            .foregroundStyle(Theme.sage)
            .symbolRenderingMode(.hierarchical)
            .frame(width: 88, height: 88)
            .background(
                Circle().fill(Theme.sage.opacity(Theme.Opacity.soft))
            )
            .accessibilityHidden(true)
    }

    // MARK: - Buttons

    private var primaryButton: some View {
        Button {
            appState.pendingAddSheet = .income(preferRecurring: true)
        } label: {
            Text("Add income")
                .font(Typography.Body.emphasis)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .fill(Theme.sage)
                )
        }
        .buttonStyle(.plain)
        .accessibilityHint("Add a recurring paycheck or other income source.")
    }

    private var secondaryButton: some View {
        Button {
            appState.pendingAddSheet = .bill()
        } label: {
            Text("Or add a bill")
                .font(Typography.Body.regular)
                .foregroundStyle(Theme.sage)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Record a recurring bill instead.")
    }
}

// MARK: - Preview

#Preview {
    OverviewEmptyHero()
        .environment(AppState())
        .background(Theme.background)
}
