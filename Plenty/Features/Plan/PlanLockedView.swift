//
//  PlanLockedView.swift
//  Plenty
//
//  Target path: Plenty/Features/Plan/PlanLockedView.swift
//
//  Phase 6 (v2): the locked view shown when a free user is on a Pro
//  mode of the Plan tab (Outlook, Save, or Trends). Accounts is
//  always free in v2, so this view never shows for that mode.
//
//  Copy adapts to the specific locked mode — when the user tapped
//  "Outlook," the header reads "Outlook is part of Plenty Pro" rather
//  than the v1 "Plan is part of Plenty Pro" (which would be wrong now
//  that Accounts under Plan is free).
//
//  The other two Pro modes still appear as preview tiles for context
//  — the user is one tap away from any of them, and showing the full
//  Pro lineup helps the unlock decision.
//

import SwiftUI

struct PlanLockedView: View {

    let lockedMode: PlanMode

    @State private var showingPaywall = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                header

                VStack(spacing: 12) {
                    ForEach(modeOrder, id: \.self) { mode in
                        previewTile(
                            for: mode,
                            isPrimary: mode == lockedMode
                        )
                    }
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

    // MARK: - Mode Ordering

    /// Locked mode first, others after — keeps the user's intent at
    /// the top of the page.
    private var modeOrder: [PlanMode] {
        let proModes: [PlanMode] = [.outlook, .save, .trends]
        let others = proModes.filter { $0 != lockedMode }
        return [lockedMode] + others
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Theme.sage)
                .symbolRenderingMode(.hierarchical)
                .padding(.bottom, 4)

            Text(headerTitle)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)

            Text("Unlock once. Yours forever.")
                .font(Typography.Body.regular)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var headerTitle: String {
        switch lockedMode {
        case .outlook: return "Outlook is part of Plenty Pro"
        case .save:    return "Save is part of Plenty Pro"
        case .trends:  return "Trends is part of Plenty Pro"
        case .accounts: return "Plenty Pro"  // never reached in normal flow
        }
    }

    // MARK: - Preview Tiles

    private func previewTile(for mode: PlanMode, isPrimary: Bool) -> some View {
        let copy = previewCopy(for: mode)

        return HStack(alignment: .top, spacing: 14) {
            Image(systemName: mode.iconName)
                .font(.title3.weight(.medium))
                .foregroundStyle(isPrimary ? .white : Theme.sage)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 40, height: 40)
                .background(
                    Circle().fill(isPrimary ? AnyShapeStyle(Theme.sage) : AnyShapeStyle(Theme.sage.opacity(Theme.Opacity.soft)))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(copy.title)
                    .font(Typography.Body.emphasis)
                    .foregroundStyle(.primary)
                Text(copy.description)
                    .font(Typography.Body.regular)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.cardSurface)
                .shadow(
                    color: isPrimary ? Theme.sage.opacity(0.15) : .black.opacity(0.04),
                    radius: isPrimary ? 8 : 3,
                    x: 0,
                    y: isPrimary ? 4 : 2
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .stroke(isPrimary ? Theme.sage : .clear, lineWidth: 1.5)
        )
    }

    private func previewCopy(for mode: PlanMode) -> (title: String, description: String) {
        switch mode {
        case .outlook:
            return (
                "Outlook",
                "Twelve months ahead, projected from your real income and bills."
            )
        case .save:
            return (
                "Save",
                "Goals, contributions, and a debt payoff plan."
            )
        case .trends:
            return (
                "Trends",
                "Six months of net worth and spending by category."
            )
        case .accounts:
            return (
                "Accounts",
                "Track your real cash position. Free under Plan."
            )
        }
    }

    // MARK: - Unlock + Restore

    private var unlockButton: some View {
        Button {
            showingPaywall = true
        } label: {
            HStack {
                Spacer()
                Text("Unlock Plenty Pro")
                    .font(Typography.Body.emphasis)
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.sage)
            )
        }
        .buttonStyle(.plain)
    }

    private var restoreLink: some View {
        Button {
            showingPaywall = true
        } label: {
            Text("Already purchased? Restore.")
                .font(Typography.Support.footnote)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Outlook locked") {
    PlanLockedView(lockedMode: .outlook)
}

#Preview("Save locked") {
    PlanLockedView(lockedMode: .save)
}

#Preview("Trends locked") {
    PlanLockedView(lockedMode: .trends)
}
