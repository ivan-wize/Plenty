//
//  AddAccountSheet.swift
//  Plenty
//
//  Target path: Plenty/Features/Accounts/AddAccountSheet.swift
//
//  Combined add and edit flow. When `account == nil`, runs the two-step
//  add (pick kind → fill details). When `account != nil`, jumps
//  straight to details with fields pre-populated.
//
//  Credit cards expose:
//    • interestRate
//    • minimumPayment
//    • creditLimit
//    • statementDay
//    • statementBalance     ← new for Plenty (Phase 0 Decision 3.2)
//
//  The statementBalance field is the crux of the refined hero math:
//  it's what BudgetEngine subtracts from the spendable number for
//  upcoming statement dates. Until the user fills it in, the hero
//  treats this card as "no statement due" — optimistic but correct.
//

import SwiftUI
import SwiftData

struct AddAccountSheet: View {

    let account: Account?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - Step

    private enum Step { case pickKind, fillDetails }
    @State private var step: Step

    // MARK: - Form State

    @State private var kind: AccountCategory.Kind
    @State private var category: AccountCategory
    @State private var name: String = ""
    @State private var balance: Decimal = 0
    @State private var interestRate: Decimal = 0
    @State private var minimumPayment: Decimal = 0
    @State private var creditLimit: Decimal = 0
    @State private var statementDay: Int = 1
    @State private var statementBalance: Decimal = 0
    @State private var note: String = ""

    // MARK: - Init

    init(account: Account? = nil) {
        self.account = account

        if let account {
            _step = State(initialValue: .fillDetails)
            _kind = State(initialValue: account.kind)
            _category = State(initialValue: account.category)
            _name = State(initialValue: account.name)
            _balance = State(initialValue: account.balance)
            _interestRate = State(initialValue: account.interestRate ?? 0)
            _minimumPayment = State(initialValue: account.minimumPayment ?? 0)
            _creditLimit = State(initialValue: account.creditLimitOrOriginalBalance ?? 0)
            _statementDay = State(initialValue: account.statementDay ?? 1)
            _statementBalance = State(initialValue: account.statementBalance ?? 0)
            _note = State(initialValue: account.note ?? "")
        } else {
            _step = State(initialValue: .pickKind)
            _kind = State(initialValue: .cash)
            _category = State(initialValue: .debit)
        }
    }

    private var isEditing: Bool { account != nil }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .pickKind:    kindPickerStep
                case .fillDetails: detailsStep
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
        }
    }

    // MARK: - Step 1: Pick Kind

    private var kindPickerStep: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(AccountCategory.Kind.allCases) { kind in
                    kindTile(for: kind)
                }
            }
            .padding(16)
        }
        .background(Theme.background)
    }

    private func kindTile(for kind: AccountCategory.Kind) -> some View {
        Button {
            self.kind = kind
            self.category = AccountCategory.categories(for: kind).first ?? .debit
            self.step = .fillDetails
        } label: {
            HStack(spacing: 14) {
                Image(systemName: kind.iconName)
                    .font(.title2.weight(.medium))
                    .foregroundStyle(Theme.sage)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.sage.opacity(Theme.Opacity.soft)))

                VStack(alignment: .leading, spacing: 3) {
                    Text(kind.displayName)
                        .font(Typography.Title.small)
                    Text(kind.tileDescription)
                        .font(Typography.Support.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.cardSurface)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 2: Details

    private var detailsStep: some View {
        Form {
            nameSection

            if AccountCategory.categories(for: kind).count > 1 {
                categorySection
            }

            balanceSection

            if kind == .credit || kind == .loan {
                termsSection
            }

            if kind == .credit {
                statementSection
            }

            noteSection
        }
    }

    private var nameSection: some View {
        Section("Name") {
            TextField("e.g. Chase Checking", text: $name)
                .textInputAutocapitalization(.words)
        }
    }

    private var categorySection: some View {
        Section("Category") {
            Picker("Category", selection: $category) {
                ForEach(AccountCategory.categories(for: kind)) { cat in
                    Label(cat.displayName, systemImage: cat.iconName).tag(cat)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var balanceSection: some View {
        Section {
            CurrencyField(value: $balance, prompt: "0", accent: kind == .credit || kind == .loan ? Theme.terracotta : Theme.sage)
        } header: {
            Text(balanceLabel)
        } footer: {
            Text(balanceFooter)
                .font(Typography.Support.caption)
        }
    }

    private var termsSection: some View {
        Section {
            HStack {
                Text("APR")
                Spacer()
                CurrencyField(value: $interestRate, prompt: "0", accent: .secondary)
                    .frame(maxWidth: 120)
                Text("%").foregroundStyle(.secondary)
            }
            HStack {
                Text("Minimum")
                Spacer()
                CurrencyField(value: $minimumPayment, prompt: "0", accent: .secondary)
                    .frame(maxWidth: 140)
            }
            HStack {
                Text(kind == .credit ? "Credit limit" : "Original balance")
                Spacer()
                CurrencyField(value: $creditLimit, prompt: "0", accent: .secondary)
                    .frame(maxWidth: 140)
            }
        } header: {
            Text(kind == .credit ? "Card terms" : "Loan terms")
        } footer: {
            Text("Used for payoff projections and utilization. All optional.")
                .font(Typography.Support.caption)
        }
    }

    private var statementSection: some View {
        Section {
            Picker("Statement closes", selection: $statementDay) {
                ForEach(1...28, id: \.self) { day in
                    Text("Day \(day)").tag(day)
                }
            }
            HStack {
                Text("Statement balance")
                Spacer()
                CurrencyField(value: $statementBalance, prompt: "0", accent: Theme.terracotta)
                    .frame(maxWidth: 140)
            }
        } header: {
            Text("Statement")
        } footer: {
            Text("Plenty subtracts your statement balance from your spendable when the statement falls before your next paycheck. Update this each month after your statement closes.")
                .font(Typography.Support.caption)
        }
    }

    private var noteSection: some View {
        Section("Note (optional)") {
            TextField("e.g. ending 4242, joint with partner", text: $note, axis: .vertical)
                .lineLimit(1...3)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Cancel", role: .cancel) { dismiss() }
        }
        if step == .fillDetails {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isEditing ? "Save" : "Add") { save() }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
            }
        }
    }

    // MARK: - Save

    private func save() {
        if let account {
            account.name = name.trimmingCharacters(in: .whitespaces)
            account.category = category
            account.interestRate = (kind == .credit || kind == .loan) && interestRate > 0 ? interestRate : nil
            account.minimumPayment = (kind == .credit || kind == .loan) && minimumPayment > 0 ? minimumPayment : nil
            account.creditLimitOrOriginalBalance = (kind == .credit || kind == .loan) && creditLimit > 0 ? creditLimit : nil
            account.statementDay = kind == .credit ? statementDay : nil
            account.statementBalance = kind == .credit && statementBalance > 0 ? statementBalance : nil
            account.note = note.trimmingCharacters(in: .whitespaces).isEmpty ? nil : note
            account.touch()

            if balance != account.balance {
                let snapshot = account.recordNewBalance(balance)
                modelContext.insert(snapshot)
            }
        } else {
            let new = Account(
                name: name.trimmingCharacters(in: .whitespaces),
                category: category,
                balance: balance,
                interestRate: (kind == .credit || kind == .loan) && interestRate > 0 ? interestRate : nil,
                minimumPayment: (kind == .credit || kind == .loan) && minimumPayment > 0 ? minimumPayment : nil,
                creditLimitOrOriginalBalance: (kind == .credit || kind == .loan) && creditLimit > 0 ? creditLimit : nil,
                statementDay: kind == .credit ? statementDay : nil,
                statementBalance: kind == .credit && statementBalance > 0 ? statementBalance : nil,
                note: note.trimmingCharacters(in: .whitespaces).isEmpty ? nil : note
            )
            modelContext.insert(new)
            modelContext.insert(AccountBalance(account: new, balance: balance))
        }

        try? modelContext.save()
        dismiss()
    }

    // MARK: - Labels

    private var navigationTitle: String {
        if isEditing { return "Edit Account" }
        switch step {
        case .pickKind:    return "Add Account"
        case .fillDetails: return "New \(kind.displayName)"
        }
    }

    private var balanceLabel: String {
        switch kind {
        case .cash:       return "Current balance"
        case .credit:     return "Currently owed"
        case .investment: return "Current value"
        case .loan:       return "Currently owed"
        }
    }

    private var balanceFooter: String {
        switch kind {
        case .cash:       return "What's in the account right now."
        case .credit:     return "What you currently owe, not your credit limit."
        case .investment: return "Current market value."
        case .loan:       return "What you currently owe on the loan."
        }
    }
}

// MARK: - Kind Helpers

private extension AccountCategory.Kind {
    var iconName: String {
        switch self {
        case .cash:       return "banknote"
        case .credit:     return "creditcard"
        case .investment: return "chart.line.uptrend.xyaxis"
        case .loan:       return "doc.text"
        }
    }

    var tileDescription: String {
        switch self {
        case .cash:       return "Checking, savings, cash on hand."
        case .credit:     return "Credit cards. Track your balance and statement."
        case .investment: return "Brokerage, retirement, real estate, valuable assets."
        case .loan:       return "Student loan, mortgage, auto loan, personal loan."
        }
    }
}
