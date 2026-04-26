//
//  SetupChecklistView.swift
//  Plenty
//
//  Target path: Plenty/Features/Home/SetupChecklistView.swift
//
//  Empty-state checklist for new users. Three rows:
//    1. Add a paycheck
//    2. Add a cash account
//    3. Add a bill
//
//  Each completed row gets a check; remaining rows are tappable.
//  Phase 4 callbacks are no-ops; Phase 5 wires them to the right
//  sheets when those exist. Renders nothing once all three are done.
//

import SwiftUI

struct SetupChecklistView: View {

    let hasIncome: Bool
    let hasCashAccount: Bool
    let hasBills: Bool

    var onAddIncome: () -> Void = {}
    var onAddAccount: () -> Void = {}
    var onAddBill: () -> Void = {}

    // MARK: - Body

    var body: some View {
        if isComplete {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                header

                VStack(spacing: 0) {
                    row(
                        label: "Add a paycheck",
                        complete: hasIncome,
                        action: onAddIncome
                    )
                    divider
                    row(
                        label: "Add a cash account",
                        complete: hasCashAccount,
                        action: onAddAccount
                    )
                    divider
                    row(
                        label: "Add a bill",
                        complete: hasBills,
                        action: onAddBill
                    )
                }
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .fill(Theme.cardSurface)
                )
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Get set up")
                .font(Typography.Title.small)
                .foregroundStyle(.primary)

            Text("Three steps and your number starts to mean something.")
                .font(Typography.Support.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Row

    private func row(
        label: String,
        complete: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: complete ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.regular))
                    .foregroundStyle(complete ? Theme.sage : .tertiary)
                    .symbolRenderingMode(.hierarchical)

                Text(label)
                    .font(Typography.Body.regular)
                    .foregroundStyle(complete ? .secondary : .primary)
                    .strikethrough(complete, color: .secondary)

                Spacer()

                if !complete {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(complete)
        .accessibilityLabel(complete ? "\(label), complete" : label)
        .accessibilityAddTraits(complete ? [] : .isButton)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.secondary.opacity(Theme.Opacity.hairline))
            .frame(height: 0.5)
            .padding(.leading, 50)
    }

    // MARK: - Computed

    private var isComplete: Bool {
        hasIncome && hasCashAccount && hasBills
    }
}

#Preview("None complete") {
    SetupChecklistView(hasIncome: false, hasCashAccount: false, hasBills: false)
        .padding(.vertical)
        .background(Theme.background)
}

#Preview("One complete") {
    SetupChecklistView(hasIncome: true, hasCashAccount: false, hasBills: false)
        .padding(.vertical)
        .background(Theme.background)
}

#Preview("All complete (renders nothing)") {
    SetupChecklistView(hasIncome: true, hasCashAccount: true, hasBills: true)
        .padding(.vertical)
        .background(Theme.background)
}
