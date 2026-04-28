//
//  BillEditorSheet.swift
//  Plenty
//
//  Target path: Plenty/Features/Add/BillEditorSheet.swift
//
//  Combined add and edit for a bill. Fields: amount, name, due day,
//  category, source account. Recurring is implicit (every bill uses
//  the standard monthly RecurringRule for its due day).
//
//  Phase 5 keeps recurrence simple: monthly only. If users need
//  quarterly bills (HOA dues, insurance), they can add manually each
//  time. A more flexible recurrence picker arrives later if requested.
//

import SwiftUI
import SwiftData

struct BillEditorSheet: View {

    let bill: Transaction?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Account.sortOrder) private var allAccounts: [Account]

    @State private var amount: Decimal = 0
    @State private var name: String = ""
    @State private var dueDay: Int = 1
    @State private var category: TransactionCategory?
    @State private var sourceAccount: Account?

    @State private var showingCategoryPicker = false
    @State private var showingAccountPicker = false
    @State private var showDeleteConfirmation = false

    @FocusState private var nameFocused: Bool

    init(bill: Transaction? = nil) {
        self.bill = bill
        if let bill {
            _amount = State(initialValue: bill.amount)
            _name = State(initialValue: bill.name)
            _dueDay = State(initialValue: bill.dueDay)
            _category = State(initialValue: bill.category)
            _sourceAccount = State(initialValue: bill.sourceAccount)
        }
    }

    private var isEditing: Bool { bill != nil }

    private var canSave: Bool {
        amount > 0 && !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                amountSection
                nameSection
                dueDaySection
                categorySection
                if !allAccounts.isEmpty {
                    accountSection
                }
                if isEditing {
                    deleteSection
                }
            }
            .navigationTitle(isEditing ? "Edit Bill" : "Add Bill")
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
            .confirmationDialog(
                "Delete this bill?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { delete() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This deletes only this month's entry. Future months are unaffected.")
            }
            .onAppear {
                if !isEditing && sourceAccount == nil {
                    sourceAccount = AccountDerivations.defaultSpendingSource(allAccounts)
                }
                if !isEditing { nameFocused = true }
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
        Section("Bill name") {
            TextField("e.g. Rent, Internet, Apple Music", text: $name)
                .textInputAutocapitalization(.words)
                .focused($nameFocused)
        }
    }

    private var dueDaySection: some View {
        Section {
            Picker("Due day", selection: $dueDay) {
                ForEach(1...28, id: \.self) { day in
                    Text(day.ordinalString).tag(day)
                }
            }
        } footer: {
            Text("Bills repeat monthly on this day.")
                .font(Typography.Support.caption)
        }
    }

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

    private var accountSection: some View {
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

    private var deleteSection: some View {
        Section {
            Button("Delete this bill", role: .destructive) {
                showDeleteConfirmation = true
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Cancel", role: .cancel) { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(isEditing ? "Save" : "Add") { save() }
                .fontWeight(.semibold)
                .disabled(!canSave)
        }
    }

    // MARK: - Actions

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let cal = Calendar.current
        let now = Date.now

        if let bill {
            bill.amount = amount
            bill.name = trimmedName
            bill.dueDay = dueDay
            bill.category = category
            bill.sourceAccount = sourceAccount
            try? modelContext.save()
        } else {
            let m = cal.component(.month, from: now)
            let y = cal.component(.year, from: now)
            let new = Transaction.bill(
                name: trimmedName,
                amount: amount,
                dueDay: dueDay,
                month: m,
                year: y,
                category: category,
                sourceAccount: sourceAccount,
                recurringRule: .monthly(onDay: dueDay, startingFrom: now)
            )
            modelContext.insert(new)
            try? modelContext.save()
        }

        dismiss()
    }

    private func delete() {
        guard let bill else { return }
        modelContext.delete(bill)
        try? modelContext.save()
        dismiss()
    }
}
