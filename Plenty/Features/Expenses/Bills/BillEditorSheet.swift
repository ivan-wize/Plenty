//
//  BillEditorSheet.swift
//  Plenty
//
//  Target path: Plenty/Features/Expenses/Bills/BillEditorSheet.swift
//
//  Phase 10 cleanup: removed the unused `initialImage: Data? = nil`
//  init parameter that P5 added for forward compatibility. Bills don't
//  store image data on the model today (`Transaction.bill` has no
//  equivalent of `receiptImageData`), so the parameter dropped its
//  argument silently. The cleanest API doesn't accept what it doesn't
//  use; if v2.1 wires bill images, the parameter can come back along
//  with the model field.
//
//  Three init paths now:
//
//    BillEditorSheet()
//      → Add a new bill from scratch.
//
//    BillEditorSheet(bill: existing)
//      → Edit an existing bill. Save updates the record.
//
//    BillEditorSheet(billDraft: draft)
//      → Add a new bill pre-filled from a scanned bill/invoice.
//
//  Recurrence remains monthly-only on the form (matching v1's intent).
//  When a BillDraft arrives with quarterly or annually, the user is
//  warned in a footer and can adjust the dueDay manually for the
//  current month — quarterly/annual cadence is set up by adding a
//  bill once each cycle. A flexible recurrence picker is a v2.1 follow-on.
//

import SwiftUI
import SwiftData

struct BillEditorSheet: View {

    let bill: Transaction?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(MonthScope.self) private var monthScope

    @Query(sort: \Account.sortOrder) private var allAccounts: [Account]

    @State private var amount: Decimal = 0
    @State private var name: String = ""
    @State private var dueDay: Int = 1
    @State private var category: TransactionCategory?
    @State private var sourceAccount: Account?

    @State private var draftRecurrence: BillDraft.Recurrence?

    @State private var showingCategoryPicker = false
    @State private var showingAccountPicker = false
    @State private var showDeleteConfirmation = false

    @FocusState private var nameFocused: Bool

    // MARK: - Init

    init(
        bill: Transaction? = nil,
        billDraft: BillDraft? = nil
    ) {
        self.bill = bill

        if let bill {
            _amount = State(initialValue: bill.amount)
            _name = State(initialValue: bill.name)
            _dueDay = State(initialValue: bill.dueDay)
            _category = State(initialValue: bill.category)
            _sourceAccount = State(initialValue: bill.sourceAccount)
        } else if let billDraft {
            if let draftAmount = billDraft.amount {
                _amount = State(initialValue: draftAmount)
            }
            if let vendor = billDraft.vendor {
                _name = State(initialValue: vendor)
            }
            if let day = billDraft.dueDay, (1...31).contains(day) {
                _dueDay = State(initialValue: min(day, 28))
            }
            _category = State(initialValue: billDraft.category)
            _draftRecurrence = State(initialValue: billDraft.recurrence)
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
                if let recurrence = draftRecurrence, recurrence != .monthly {
                    recurrenceWarningSection(recurrence)
                }
                categorySection
                if !allAccounts.isEmpty {
                    accountSection
                }
                if isEditing {
                    deleteSection
                }
            }
            .navigationTitle(isEditing ? "Edit bill" : "Add bill")
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
                if !isEditing && draftRecurrence == nil {
                    nameFocused = true
                }
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

    private func recurrenceWarningSection(_ recurrence: BillDraft.Recurrence) -> some View {
        Section {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle")
                    .foregroundStyle(Theme.amber)
                    .symbolRenderingMode(.hierarchical)
                Text("This looks like a \(recurrence.displayName.lowercased()) bill. Plenty saves it as monthly for now — you'll add it again each cycle until \(recurrence == .quarterly ? "quarterly" : "annual") cadence is built in.")
                    .font(Typography.Support.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
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

        if let bill {
            bill.amount = amount
            bill.name = trimmedName
            bill.dueDay = dueDay
            bill.category = category
            bill.sourceAccount = sourceAccount
            try? modelContext.save()
        } else {
            // New bills land in the currently scoped month, not the
            // calendar month, so users back-filling history (or
            // pre-planning) get correct placement.
            let new = Transaction.bill(
                name: trimmedName,
                amount: amount,
                dueDay: dueDay,
                month: monthScope.month,
                year: monthScope.year,
                category: category,
                sourceAccount: sourceAccount,
                recurringRule: .monthly(onDay: dueDay, startingFrom: .now)
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
