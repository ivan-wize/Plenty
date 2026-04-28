//
//  WatchHomeView.swift
//  Plenty
//
//  Target path: PlentyWatch/WatchHomeView.swift
//  Watch target: PlentyWatch
//
//  Phase 8 (v2): Watch home view aligned with the v2 hero. Reads
//  `snapshot.monthlyBudgetRemaining` instead of `spendable` and uses
//  the v2 two-state color logic (sage / terracotta).
//
//  Three sections:
//    1. Hero — monthlyBudgetRemaining, big and centered
//    2. Bills glance — count + total of unpaid bills, tap to checklist
//    3. Income glance — expected income today/tomorrow with quick confirm
//
//  Sections render only when relevant. Empty home (no bills, no
//  income) shows just the hero.
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

    /// Expected income due today or earlier.
    private var pendingIncome: Transaction? {
        let cal = Calendar.current
        return allTransactions
            .filter { $0.kind == .income && $0.incomeStatus == .expected }
            .filter { $0.date <= cal.date(byAdding: .day, value: 1, to: .now)! }
            .sorted { $0.date < $1.date }
            .first
    }

    private var isOverBudget: Bool {
        snapshot.monthlyBudgetRemaining < 0
    }

    private var hasNoData: Bool {
        snapshot.zone == .empty
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

                    if unpaidBills.isEmpty && pendingIncome == nil && !hasNoData {
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
            Text(captionText)
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

            if let burn = snapshot.sustainableDailyBurn,
               burn > 0,
               !isOverBudget {
                Text("~\(burn.asCompactCurrency())/day")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            } else if isOverBudget {
                Text("Over budget")
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
                    Text("\(unpaidBills.count) \(unpaidBills.count == 1 ? "bill" : "bills")")
                        .font(.system(size: 13, weight: .semibold))
                    Text(unpaidBills.reduce(Decimal.zero) { $0 + $1.amount }.asCompactCurrency())
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.secondary.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Confirm Income Card

    private func confirmIncomeCard(for income: Transaction) -> some View {
        NavigationLink {
            WatchConfirmIncomeView(income: income)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.sage)

                VStack(alignment: .leading, spacing: 1) {
                    Text(income.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text("Tap to confirm")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text((income.expectedAmount > 0 ? income.expectedAmount : income.amount).asCompactCurrency())
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.sage)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.sage.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - All Caught Up

    private var allCaughtUpCard: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.sage)

            Text("All caught up")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    // MARK: - Computed

    private var captionText: String {
        if hasNoData {
            return "Budget"
        }
        return isOverBudget ? "Over by" : "Left"
    }

    private var formattedAmount: String {
        let abs = snapshot.monthlyBudgetRemaining < 0
            ? -snapshot.monthlyBudgetRemaining
            : snapshot.monthlyBudgetRemaining
        return abs.asCompactCurrency()
    }

    private var numberColor: Color {
        if hasNoData { return .secondary }
        return isOverBudget ? Theme.terracotta : Theme.sage
    }
}
