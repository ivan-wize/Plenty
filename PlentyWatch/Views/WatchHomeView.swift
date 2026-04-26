//
//  WatchHomeView.swift
//  Plenty
//
//  Target path: PlentyWatch/WatchHomeView.swift
//  Watch target: PlentyWatch
//
//  The Watch home view. Three sections:
//
//    1. Hero — spendable number, big and centered
//    2. Bills glance — count + total of unpaid bills, tap to checklist
//    3. Income glance — expected income today/tomorrow with quick confirm
//
//  Sections render only when relevant. Empty home (no bills, no income)
//  shows just the hero.
//

import SwiftUI
import SwiftData

struct WatchHomeView: View {

    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Account.sortOrder) private var allAccounts: [Account]
    @Query private var allTransactions: [Transaction]
    @Query private var allSavingsGoals: [SavingsGoal]

    private var month: Int { Calendar.current.component(.month, from: .now) }
    private var year: Int { Calendar.current.component(.year, from: .now) }

    // MARK: - Derived

    private var snapshot: PlentySnapshot {
        BudgetEngine.calculate(
            accounts: AccountDerivations.activeAccounts(allAccounts),
            transactions: allTransactions,
            savingsGoals: allSavingsGoals,
            month: month,
            year: year
        )
    }

    private var unpaidBills: [Transaction] {
        TransactionProjections.bills(allTransactions, month: month, year: year)
            .filter { !$0.isPaid }
            .sorted { $0.dueDay < $1.dueDay }
    }

    /// Expected income due today or earlier (a paycheck waiting to be confirmed).
    private var pendingIncome: Transaction? {
        let cal = Calendar.current
        return allTransactions
            .filter { $0.kind == .income && $0.incomeStatus == .expected }
            .filter { $0.date <= cal.date(byAdding: .day, value: 1, to: .now)! }
            .sorted { $0.date < $1.date }
            .first
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    heroSection

                    if let pending = pendingIncome {
                        confirmIncomeCard(for: pending)
                    }

                    if !unpaidBills.isEmpty {
                        billsCard
                    }

                    if unpaidBills.isEmpty && pendingIncome == nil && snapshot.zone != .empty {
                        allCaughtUpCard
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 8)
            }
            .navigationTitle("Plenty")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 4) {
            Text("Spendable")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            Text(formattedAmount)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(numberColor)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            if let burn = snapshot.sustainableDailyBurn, burn > 0, snapshot.zone != .over {
                Text("~\(burn.asCompactCurrency())/day")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            } else if snapshot.zone == .over {
                Text("Over your margin")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.terracotta)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Bills Card

    private var billsCard: some View {
        NavigationLink {
            WatchBillsView(bills: unpaidBills)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.sage)

                VStack(alignment: .leading, spacing: 1) {
                    Text("\(unpaidBills.count) \(unpaidBills.count == 1 ? "bill" : "bills") due")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(snapshot.billsRemaining.asCompactCurrency())
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.sage.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Confirm Income Card

    private func confirmIncomeCard(for income: Transaction) -> some View {
        NavigationLink {
            WatchConfirmIncomeView(transaction: income)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.sage)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Confirm \(income.name)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(income.expectedAmount.asCompactCurrency())
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.sage.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - All Caught Up

    private var allCaughtUpCard: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(Theme.sage)
            Text("All caught up")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Computed

    private var formattedAmount: String {
        let abs = snapshot.spendable < 0 ? -snapshot.spendable : snapshot.spendable
        let formatted = abs.asCompactCurrency()
        return snapshot.spendable < 0 ? "−\(formatted)" : formatted
    }

    private var numberColor: Color {
        switch snapshot.zone {
        case .empty:   return .secondary
        case .safe:    return .primary
        case .warning: return Theme.amber
        case .over:    return Theme.terracotta
        }
    }
}

private extension Decimal {
    func asCompactCurrency() -> String {
        let value = NSDecimalNumber(decimal: self).doubleValue
        let absValue = abs(value)
        if absValue >= 1_000_000 {
            return String(format: "$%.1fM", value / 1_000_000)
        }
        if absValue >= 10_000 {
            return String(format: "$%.0fk", value / 1_000)
        }
        if absValue >= 1_000 {
            return String(format: "$%.1fk", value / 1_000)
        }
        return String(format: "$%.0f", value)
    }
}
