//
//  PlentyProSection.swift
//  Plenty
//
//  Target path: Plenty/Features/Settings/PlentyProSection.swift
//
//  Settings section that surfaces Pro state. Two states:
//
//    Locked — shows the price and an Upgrade button that opens
//             PaywallSheet.
//    Unlocked — shows "Plenty Pro" with a small sage badge and a
//             Restore button that re-runs StoreKit verification.
//
//  In both states a "Restore Purchases" row is available for users on
//  a new device. Pro doesn't expire and isn't a subscription, so
//  there's no renewal date or management link to surface.
//

import SwiftUI

struct PlentyProSection: View {

    @Environment(AppState.self) private var appState
    @Environment(StoreKitManager.self) private var storeKit

    @State private var showingPaywall = false
    @State private var isRestoring = false
    @State private var restoreMessage: String?

    var body: some View {
        Section {
            if appState.isProUnlocked {
                unlockedRow
            } else {
                lockedRow
            }

            restoreRow
        } header: {
            Text("Plenty Pro")
        } footer: {
            footerText
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallSheet()
        }
        .alert("Restore Purchases", isPresented: restoreAlertBinding) {
            Button("OK", role: .cancel) {
                restoreMessage = nil
            }
        } message: {
            Text(restoreMessage ?? "")
        }
    }

    // MARK: - Rows

    private var unlockedRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(Theme.sage)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text("Plenty Pro")
                    .font(Typography.Body.emphasis)
                Text("Thanks for supporting an indie app.")
                    .font(Typography.Support.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            ProBadge()
        }
        .padding(.vertical, 4)
    }

    private var lockedRow: some View {
        Button {
            showingPaywall = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "leaf")
                    .foregroundStyle(Theme.sage)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Upgrade to Pro")
                        .font(Typography.Body.emphasis)
                        .foregroundStyle(.primary)
                    Text("\(storeKit.formattedPrice) once. The Plan tab unlocked, forever.")
                        .font(Typography.Support.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var restoreRow: some View {
        Button {
            restorePurchases()
        } label: {
            HStack {
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(.secondary)
                    .frame(width: 28)
                Text("Restore Purchases")
                    .foregroundStyle(.primary)
                Spacer()
                if isRestoring {
                    ProgressView().controlSize(.small)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isRestoring)
    }

    // MARK: - Footer

    private var footerText: Text {
        if appState.isProUnlocked {
            return Text("Pro is a one-time purchase, so there's nothing to manage. If you reinstall on a new device, tap Restore Purchases to get it back.")
        } else {
            return Text("One payment. Unlocks the Plan tab: 90-day Outlook, savings goals, debt payoff, trends, and net worth detail. No subscription, ever.")
        }
    }

    // MARK: - Restore

    private var restoreAlertBinding: Binding<Bool> {
        Binding(
            get: { restoreMessage != nil },
            set: { if !$0 { restoreMessage = nil } }
        )
    }

    private func restorePurchases() {
        isRestoring = true
        Task {
            let restored = await storeKit.restorePurchases()
            isRestoring = false
            restoreMessage = restored
                ? "Pro restored. Welcome back."
                : "No Pro purchase found on this Apple ID."
        }
    }
}
