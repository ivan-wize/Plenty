//
//  PlanLockedView.swift
//  Plenty
//
//  Target path: Plenty/Features/Plan/PlanLockedView.swift
//
//  The Plan tab as seen by free users. Three feature preview tiles
//  with calm descriptions, one Unlock button. Tap → PaywallSheet.
//

import SwiftUI

struct PlanLockedView: View {

    @State private var showingPaywall = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                header

                VStack(spacing: 12) {
                    previewTile(
                        icon: "calendar",
                        title: "Outlook",
                        description: "Twelve months ahead, projected from your real income and bills."
                    )
                    previewTile(
                        icon: "leaf",
                        title: "Save",
                        description: "Goals, contributions, and a debt payoff plan."
                    )
                    previewTile(
                        icon: "chart.bar",
                        title: "Trends",
                        description: "Six months of net worth and spending by category."
                    )
                }

                unlockButton

                restoreLink
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
        }
        .background(Theme.background)
        .sheet(isPresented: $showingPaywall) {
            PaywallSheet()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Theme.sage)
                .symbolRenderingMode(.hierarchical)
                .padding(.bottom, 4)

            Text("Plan is part of Plenty Pro")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)

            Text("Unlock once. Yours forever.")
                .font(Typography.Body.regular)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    // MARK: - Preview Tile

    private func previewTile(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3.weight(.medium))
                .foregroundStyle(Theme.sage)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Theme.sage.opacity(Theme.Opacity.soft)))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(Typography.Body.emphasis)
                        .foregroundStyle(.primary)
                    ProBadge()
                }
                Text(description)
                    .font(Typography.Body.regular)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.cardSurface)
        )
    }

    // MARK: - Buttons

    private var unlockButton: some View {
        Button {
            showingPaywall = true
        } label: {
            HStack {
                Spacer()
                Text("Unlock Plan")
                    .font(Typography.Body.emphasis)
                Spacer()
            }
            .padding(.vertical, 16)
        }
        .background(Theme.sage)
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .padding(.top, 8)
    }

    private var restoreLink: some View {
        Button {
            showingPaywall = true
        } label: {
            Text("Already purchased? Restore")
                .font(Typography.Support.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }
}
