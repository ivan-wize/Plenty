//
//  AddActionSheet.swift
//  Plenty
//
//  Target path: Plenty/Features/Add/AddActionSheet.swift
//
//  The three-option chooser presented by the Add button in the tab bar.
//  Phase 2 ships a dismissable sheet with the three options wired to
//  stub callbacks. Phase 3 replaces each callback with a presentation
//  of the real sheet (AddExpenseSheet, AddIncomeSheet, BillEditorSheet).
//
//  PRD §8: Add action offers "Add expense, Add income, Add bill."
//  Voice: PRD §5. All icons in Plenty Sage; state colors (amber,
//  terracotta) are reserved for state communication per §4.3.
//

import SwiftUI

struct AddActionSheet: View {

    // MARK: - Callbacks
    //
    // Phase 2: these are no-ops. Phase 3 wires them to their real sheets
    // and records the user's choice before this sheet dismisses.

    var onAddExpense: () -> Void = {}
    var onAddIncome: () -> Void = {}
    var onAddBill: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 20)
                .padding(.bottom, 8)

            VStack(spacing: 8) {
                option(
                    icon: "cart",
                    title: "Add expense",
                    subtitle: "A one-time purchase.",
                    action: {
                        onAddExpense()
                        dismiss()
                    }
                )

                option(
                    icon: "arrow.down.circle",
                    title: "Add income",
                    subtitle: "Money arriving.",
                    action: {
                        onAddIncome()
                        dismiss()
                    }
                )

                option(
                    icon: "doc.text",
                    title: "Add bill",
                    subtitle: "A recurring obligation.",
                    action: {
                        onAddBill()
                        dismiss()
                    }
                )
            }
            .padding(.horizontal, 16)

            Spacer(minLength: 16)
        }
        .background(Theme.background)
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header

    private var header: some View {
        Text("What would you like to add?")
            .font(Typography.Title.small)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Option Row

    private func option(
        icon: String,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Theme.sage)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Theme.sage.opacity(Theme.Opacity.soft))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Typography.Body.emphasis)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(Typography.Support.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.cardSurface)
            )
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
        .sensoryFeedback(.selection, trigger: false)  // plays on each tap
    }
}

#Preview {
    AddActionSheet()
}
