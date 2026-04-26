//
//  AddIncomeSheet.swift
//  Plenty
//
//  Target path: Plenty/Features/Add/AddIncomeSheet.swift
//
//  Income entry. Two modes via a single toggle:
//
//    Recurring on:
//      Creates an IncomeSource template (frequency, amount, day of month
//      or weekday) and immediately materializes the first Transaction
//      via IncomeEntryGenerator.
//
//    Recurring off:
//      Creates a one-time .income Transaction with status .confirmed,
//      amount as confirmed, optional destination account.
//
//  Setup checklist passes preferRecurring: true so the toggle defaults
//  on. Ad-hoc Add button passes preferRecurring: false.
//

import SwiftUI
import SwiftData

struct AddIncomeSheet: View {

    let preferRecurring: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Account.sortOrder) private var allAccounts: [Account]

    @State private var amount: Decimal = 0
    @State private var name: String = ""
    @State private var destinationAccount: Account?
    @State private var date: Date = .now

    // Recurring fields
    @State private var isRecurring: Bool
    @State private var frequency: IncomeSource.Frequency = .biweekly
    @State private var dayOfMonth: Int = 1
    @State private var weekday: Int = 5  // Friday

    @State private var showingAccountPicker = false
    @FocusState private var nameFocused: Bool

    // MARK: - Init

    init(preferRecurring: Bool = false) {
        self.preferRecurring = preferRecurring
        _isRecurring = State(initialValue: preferRecurring)
    }

    private var canSave: Bool {
        amount > 0 && !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                amountSection
                nameSection
                recurringToggleSection
                if isRecurring {
                    cadenceSection
                } else {
                    dateSection
                }
                if !allAccounts.isEmpty {
                    accountSection
                }
            }
            .navigationTitle(isRecurring ? "Add Paycheck" : "Add Income")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .sheet(isPresented: $showingAccountPicker) {
                AccountPickerView(
                    selection: $destinationAccount,
                    accounts: allAccounts,
                    spendableOnly: false
                )
            }
            .onAppear {
                if destinationAccount == nil {
                    destinationAccount = AccountDerivations.defaultSpendingSource(allAccounts)
                }
                if name.isEmpty && isRecurring {
                    name = "Paycheck"
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
        } header: {
            Text(isRecurring ? "Per paycheck" : "Amount")
        }
    }

    private var nameSection: some View {
        Section("Name") {
            TextField("e.g. Paycheck, Refund, Side gig", text: $name)
                .textInputAutocapitalization(.words)
                .focused($nameFocused)
        }
    }

    private var recurringToggleSection: some View {
        Section {
            Toggle("Make this recurring", isOn: $isRecurring)
        } footer: {
            Text(isRecurring
                 ? "Plenty will expect this paycheck on each scheduled date and ask you to confirm when it lands."
                 : "A one-time entry. Won't repeat next month.")
                .font(Typography.Support.caption)
        }
    }

    @ViewBuilder
    private var cadenceSection: some View {
        Section("How often") {
            Picker("Frequency", selection: $frequency) {
                ForEach(IncomeSource.Frequency.allCases) { freq in
                    Text(freq.displayName).tag(freq)
                }
            }
            .pickerStyle(.menu)
        }

        Section {
            switch frequency {
            case .monthly:
                Picker("Day of month", selection: $dayOfMonth) {
                    ForEach(1...28, id: \.self) { day in
                        Text(day.ordinal).tag(day)
                    }
                }
            case .semimonthly:
                Picker("First day", selection: $dayOfMonth) {
                    ForEach(1...28, id: \.self) { day in
                        Text(day.ordinal).tag(day)
                    }
                }
            case .biweekly, .weekly:
                Picker("Weekday", selection: $weekday) {
                    Text("Sunday").tag(0)
                    Text("Monday").tag(1)
                    Text("Tuesday").tag(2)
                    Text("Wednesday").tag(3)
                    Text("Thursday").tag(4)
                    Text("Friday").tag(5)
                    Text("Saturday").tag(6)
                }
            }
        } header: {
            Text("When")
        }
    }

    private var dateSection: some View {
        Section {
            DatePicker("Date", selection: $date, displayedComponents: .date)
        }
    }

    private var accountSection: some View {
        Section {
            Button {
                showingAccountPicker = true
            } label: {
                HStack {
                    Text("Lands in")
                        .foregroundStyle(.primary)
                    Spacer()
                    if let destinationAccount {
                        Text(destinationAccount.name)
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

    // MARK: - Save

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        if isRecurring {
            let source = IncomeSource(
                name: trimmedName,
                expectedAmount: amount,
                frequency: frequency,
                dayOfMonth: dayOfMonth,
                secondDayOfMonth: nil,
                weekday: weekday,
                biweeklyAnchor: frequency == .biweekly || frequency == .weekly ? Date.now : nil,
                isActive: true
            )
            modelContext.insert(source)
            try? modelContext.save()

            // Materialize this month's expected entries from the new source.
            let cal = Calendar.current
            let now = Date.now
            let m = cal.component(.month, from: now)
            let y = cal.component(.year, from: now)
            try? IncomeEntryGenerator(context: modelContext).generateExpectedEntries(month: m, year: y)
        } else {
            let tx = Transaction.manualIncome(
                name: trimmedName,
                amount: amount,
                date: date,
                category: .paycheck,
                destinationAccount: destinationAccount
            )
            modelContext.insert(tx)
            try? modelContext.save()
        }

        dismiss()
    }
}
