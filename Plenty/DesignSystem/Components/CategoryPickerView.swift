//
//  CategoryPickerView.swift
//  Plenty
//
//  Target path: Plenty/Features/Add/CategoryPickerView.swift
//
//  Sheet for picking a TransactionCategory, scoped to one of:
//    • .expense  → 9 expense categories + "other"
//    • .income   → 6 income categories
//    • .transfer → 4 transfer categories
//
//  Returns nil when the user clears the selection. Used by every Add/
//  Edit sheet that asks the user to categorize a transaction.
//
//  Layout: a single grouped List with category rows. Active selection
//  shows a sage checkmark on the right. A clear-selection row appears
//  at the bottom only when something is currently selected, so the
//  picker doesn't suggest "clear" as a default action.
//

import SwiftUI

struct CategoryPickerView: View {

    // MARK: - API

    @Binding var selection: TransactionCategory?
    let scope: TransactionCategory.Scope

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - Derived

    private var categories: [TransactionCategory] {
        switch scope {
        case .expense:
            // Expense scope includes "other" as the explicit catchall.
            return TransactionCategory.expenseCases + [.other]
        case .income:
            return TransactionCategory.incomeCases
        case .transfer:
            return TransactionCategory.transferCases
        }
    }

    private var navigationTitle: String {
        switch scope {
        case .expense:  return "Category"
        case .income:   return "Income type"
        case .transfer: return "Transfer type"
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(categories) { category in
                        categoryRow(category)
                    }
                }

                if selection != nil {
                    Section {
                        Button(role: .destructive) {
                            selection = nil
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "xmark.circle")
                                    .frame(width: 28)
                                Text("Clear category")
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Row

    private func categoryRow(_ category: TransactionCategory) -> some View {
        Button {
            selection = category
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: category.iconName)
                    .font(.body)
                    .foregroundStyle(Theme.sage)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 28, height: 28)

                Text(category.displayName)
                    .foregroundStyle(.primary)

                Spacer()

                if selection == category {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.sage)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(category.displayName)
        .accessibilityAddTraits(selection == category ? [.isSelected] : [])
    }
}

// MARK: - Preview

#Preview("Expense scope") {
    StatefulCategoryPicker(scope: .expense)
}

#Preview("Income scope") {
    StatefulCategoryPicker(scope: .income)
}

private struct StatefulCategoryPicker: View {
    let scope: TransactionCategory.Scope
    @State private var selection: TransactionCategory? = nil

    var body: some View {
        CategoryPickerView(selection: $selection, scope: scope)
    }
}
