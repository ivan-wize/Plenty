//
//  CategoryPickerView.swift
//  Plenty
//
//  Target path: Plenty/DesignSystem/CategoryPickerView.swift
//
//  Modal picker for TransactionCategory. Filters by scope (expense,
//  income, transfer) and lays out categories as tappable rows with
//  icons. Selection commits the category to the binding and dismisses.
//

import SwiftUI

struct CategoryPickerView: View {

    @Binding var selection: TransactionCategory?
    let scope: TransactionCategory.Scope?

    @Environment(\.dismiss) private var dismiss

    private var categories: [TransactionCategory] {
        guard let scope else { return TransactionCategory.allCases }
        switch scope {
        case .expense:  return TransactionCategory.expenseCases
        case .income:   return TransactionCategory.incomeCases
        case .transfer: return TransactionCategory.transferCases
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(categories) { category in
                    row(for: category)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(for category: TransactionCategory) -> some View {
        Button {
            selection = category
            dismiss()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: category.iconName)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.sage)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle().fill(Theme.sage.opacity(Theme.Opacity.soft))
                    )

                Text(category.displayName)
                    .font(Typography.Body.regular)
                    .foregroundStyle(.primary)

                Spacer()

                if selection == category {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.sage)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
