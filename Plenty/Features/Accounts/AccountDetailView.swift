//
//  AccountDetailView.swift
//  Plenty
//
//  Target path: Plenty/Features/Accounts/AccountDetailView.swift
//
//  Per-account detail screen. Sections:
//    1. Header with current balance
//    2. Terms (credit/loan only): APR, minimum, limit, statement
//    3. Statement (credit only): close day + statement balance + footer
//    4. Recent transactions for this account
//
//  Toolbar: Update Balance (primary), Edit (secondary).
//
//  Replaces the prior AccountDetailView. Two changes:
//    • Recent transactions section now caps at 10 (was 20) and shows
//      a "See all N transactions →" NavigationLink at the bottom that
//      pushes AccountTransactionsView for the full filterable list.
//    • TransactionRow now passes showsAccount: false since every row
//      belongs to this account by definition.
//

import SwiftUI
import SwiftData

struct AccountDetailView: View {

    let account: Account

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @Query private var allTransactions: [Transaction]

    @State private var showingEdit = false

    private var accountTransactions: [Transaction] {
        allTransactions
            .filter { tx in
                tx.sourceAccount?.id == account.id || tx.destinationAccount?.id == account.id
            }
            .sorted { $0.date > $1.date }
    }

    private var recentTransactions: [Transaction] {
        Array(accountTransactions.prefix(10))
    }

    // MARK: - Body

    var body: some View {
        List {
            balanceSection

            if account.kind == .credit || account.kind == .loan {
                termsSection
            }

            if account.kind == .credit {
                statementSection
            }

            if let note = account.note, !note.isEmpty {
                noteSection(note)
            }

            transactionsSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(account.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        appState.pendingAddSheet = .updateBalance(account)
                    } label: {
                        Label("Update Balance", systemImage: "arrow.clockwise")
                    }
                    Button {
                        showingEdit = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            AddAccountSheet(account: account)
        }
    }

    // MARK: - Sections

    private var balanceSection: some View {
        Section {
            VStack(spacing: 8) {
                Text(account.isAsset ? "Current balance" : "Currently owed")
                    .font(Typography.Support.label)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.6)

                Text(formattedBalance)
                    .font(.system(size: 48, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(account.isAsset ? .primary : Theme.terracotta)

                Text(freshnessText)
                    .font(Typography.Support.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }

    @ViewBuilder
    private var termsSection: some View {
        Section(account.kind == .credit ? "Card Terms" : "Loan Terms") {
            if let apr = account.interestRate, apr > 0 {
                row(label: "APR", value: String(format: "%.2f%%", (apr as NSDecimalNumber).doubleValue))
            }
            if let min = account.minimumPayment, min > 0 {
                row(label: "Minimum", value: min.asPlainCurrency())
            }
            if let limit = account.creditLimitOrOriginalBalance, limit > 0 {
                row(label: account.kind == .credit ? "Credit limit" : "Original balance",
                    value: limit.asPlainCurrency())
            }
        }
    }

    @ViewBuilder
    private var statementSection: some View {
        Section {
            if let statementDay = account.statementDay {
                row(label: "Statement closes", value: "Day \(statementDay)")
            }
            if let statementBalance = account.statementBalance, statementBalance > 0 {
                row(label: "Statement balance", value: statementBalance.asPlainCurrency())
            } else {
                row(label: "Statement balance", value: "Not set")
            }
        } header: {
            Text("Statement")
        } footer: {
            if account.statementBalance == nil || account.statementBalance == 0 {
                Text("Add your statement balance so Plenty can include it in your spendable when the statement falls before your next paycheck.")
                    .font(Typography.Support.caption)
            } else {
                Text("Plenty subtracts this amount from your spendable when the statement falls before your next paycheck.")
                    .font(Typography.Support.caption)
            }
        }
    }

    private func noteSection(_ note: String) -> some View {
        Section("Note") {
            Text(note)
                .font(Typography.Body.regular)
        }
    }

    @ViewBuilder
    private var transactionsSection: some View {
        if recentTransactions.isEmpty {
            Section("Recent Activity") {
                Text("No transactions yet for this account.")
                    .font(Typography.Body.regular)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            }
        } else {
            Section {
                ForEach(recentTransactions) { tx in
                    TransactionRow(transaction: tx, showsAccount: false)
                }

                if accountTransactions.count > recentTransactions.count {
                    NavigationLink {
                        AccountTransactionsView(account: account)
                    } label: {
                        HStack {
                            Text("See all \(accountTransactions.count) transactions")
                                .font(Typography.Body.regular)
                                .foregroundStyle(Theme.sage)
                            Spacer()
                        }
                    }
                }
            } header: {
                Text("Recent Activity")
            }
        }
    }

    // MARK: - Row Helper

    private func row(label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    // MARK: - Computed

    private var formattedBalance: String {
        let formatted = account.balance.asPlainCurrency()
        return account.isAsset ? formatted : "−\(formatted)"
    }

    private var freshnessText: String {
        let days = account.daysSinceBalanceUpdate
        if days == 0 { return "Updated today" }
        if days == 1 { return "Updated yesterday" }
        return "Updated \(days)d ago"
    }
}

// MARK: - Local formatting

private extension Decimal {
    func asPlainCurrency() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "$\(self)"
    }
}
