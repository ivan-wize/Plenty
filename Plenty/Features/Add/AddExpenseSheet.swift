//
//  AddExpenseSheet.swift
//  Plenty
//
//  Target path: Plenty/Features/Add/AddExpenseSheet.swift
//
//  Quick add for a one-time expense. The most-used Add sheet.
//
//  Fields: amount, name, category (auto-detected from name; AI when
//  available, rules otherwise), source account (defaults to most-recent
//  spendable), date (defaults to today).
//

import SwiftUI
import SwiftData

struct AddExpenseSheet: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Account.sortOrder) private var allAccounts: [Account]

    @State private var amount: Decimal = 0
    @State private var name: String = ""
    @State private var category: TransactionCategory?
    @State private var sourceAccount: Account?
    @State private var date: Date = .now

    @State private var showingCategoryPicker = false
    @State private var showingAccountPicker = false

    @FocusState private var nameFocused: Bool

    private var canSave: Bool {
        amount > 0 && !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                amountSection
                nameSection
                categorySection
                accountSection
                dateSection
            }
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .sheet(isPresented: $showingCategoryPicker) {
                CategoryPickerView(selection: $category, scope: .expense)
            }
            .sheet(isPresented: $showingAccountPicker) {
                AccountPickerView(
                    selection: $sourceAccount,
                    accounts: allAccounts,
                    spendableOnly: true
                )
            }
            .onAppear {
                if sourceAccount == nil {
                    sourceAccount = AccountDerivations.defaultSpendingSource(allAccounts)
                }
            }
            .onChange(of: name) { _, newValue in
                Task { await autoDetectCategory(for: newValue) }
            }
        }
    }

    // MARK: - Sections

    private var amountSection: some View {
        Section {
            HStack {
                Text("$")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                CurrencyField(value: $amount, prompt: "0", accent: Theme.sage)
            }
        }
    }

    private var nameSection: some View {
        Section("What for?") {
            TextField("e.g. Trader Joe's, gas, coffee", text: $name)
                .textInputAutocapitalization(.words)
                .focused($nameFocused)
                .onAppear { nameFocused = true }
        }
    }

    @ViewBuilder
    private var categorySection: some View {
        Section {
            Button {
                showingCategoryPicker = true
            } label: {
                HStack {
                    Text("Category")
                        .foregroundStyle(.primary)
                    Spacer()
                    if let category {
                        HStack(spacing: 6) {
                            Image(systemName: category.iconName)
                                .foregroundStyle(Theme.sage)
                            Text(category.displayName)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Choose")
                            .foregroundStyle(.tertiary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var accountSection: some View {
        if !allAccounts.isEmpty {
            Section {
                Button {
                    showingAccountPicker = true
                } label: {
                    HStack {
                        Text("Paid from")
                            .foregroundStyle(.primary)
                        Spacer()
                        if let sourceAccount {
                            Text(sourceAccount.name)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Choose")
                                .foregroundStyle(.tertiary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var dateSection: some View {
        Section {
            DatePicker("Date", selection: $date, in: ...Date.now, displayedComponents: .date)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Cancel", role: .cancel) { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("Add") { save() }
                .fontWeight(.semibold)
                .disabled(!canSave)
        }
    }

    // MARK: - Actions

    private func save() {
        let tx = Transaction.expense(
            name: name.trimmingCharacters(in: .whitespaces),
            amount: amount,
            date: date,
            category: category,
            sourceAccount: sourceAccount
        )
        modelContext.insert(tx)
        try? modelContext.save()
        dismiss()
    }

    private func autoDetectCategory(for name: String) async {
        // Don't override if user already picked one.
        guard category == nil else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3 else { return }

        // Try AI first; fall back to rule-based.
        if let aiCategory = await AIExpenseCategorizer.categorize(trimmed) {
            await MainActor.run { category = aiCategory }
        } else {
            let ruleCategory = ExpenseCategorizer.detect(from: trimmed)
            if ruleCategory != .other {
                await MainActor.run { category = ruleCategory }
            }
        }
    }
}
