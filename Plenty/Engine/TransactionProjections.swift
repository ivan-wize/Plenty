//
//  TransactionProjections.swift
//  Plenty
//
//  Target path: Plenty/Engine/TransactionProjections.swift
//
//  Pure-function helpers over arrays of Transaction. No SwiftData, no
//  side effects. Port from Left.
//

import Foundation

enum TransactionProjections {

    // MARK: - Kind Filters

    static func bills(_ transactions: [Transaction], month: Int, year: Int, calendar: Calendar = .current) -> [Transaction] {
        transactions.filter { tx in
            tx.kind == .bill && tx.month == month && tx.year == year
        }
    }

    static func expenses(_ transactions: [Transaction], month: Int, year: Int, calendar: Calendar = .current) -> [Transaction] {
        transactions.filter { tx in
            guard tx.kind == .expense else { return false }
            let m = calendar.component(.month, from: tx.date)
            let y = calendar.component(.year, from: tx.date)
            return m == month && y == year
        }
    }

    static func income(_ transactions: [Transaction], month: Int, year: Int, calendar: Calendar = .current) -> [Transaction] {
        transactions.filter { tx in
            tx.kind == .income && tx.month == month && tx.year == year
        }
    }

    static func transfers(_ transactions: [Transaction], month: Int, year: Int, calendar: Calendar = .current) -> [Transaction] {
        transactions.filter { tx in
            guard tx.kind == .transfer else { return false }
            let m = calendar.component(.month, from: tx.date)
            let y = calendar.component(.year, from: tx.date)
            return m == month && y == year
        }
    }

    // MARK: - Upcoming / Unpaid

    static func upcomingUnpaidBills(_ bills: [Transaction], limit: Int = 5) -> [Transaction] {
        bills
            .filter { !$0.isPaid }
            .sorted { $0.dueDay < $1.dueDay }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Bill Totals

    static func billsTotal(_ bills: [Transaction]) -> Decimal {
        roundCents(bills.reduce(Decimal.zero) { $0 + $1.amount })
    }

    static func billsPaid(_ bills: [Transaction]) -> Decimal {
        roundCents(bills.filter(\.isPaid).reduce(Decimal.zero) { $0 + $1.amount })
    }

    static func billsRemaining(_ bills: [Transaction]) -> Decimal {
        roundCents(bills.filter { !$0.isPaid }.reduce(Decimal.zero) { $0 + $1.amount })
    }

    // MARK: - Expense Totals

    static func expensesTotal(_ expenses: [Transaction]) -> Decimal {
        roundCents(expenses.reduce(Decimal.zero) { $0 + $1.amount })
    }

    // MARK: - Income Totals

    static func confirmedIncomeTotal(_ income: [Transaction]) -> Decimal {
        roundCents(
            income
                .filter { $0.incomeStatus == .confirmed }
                .reduce(Decimal.zero) { $0 + ($1.confirmedAmount ?? $1.amount) }
        )
    }

    static func expectedIncomeTotal(_ income: [Transaction]) -> Decimal {
        roundCents(
            income
                .filter { $0.incomeStatus == .expected }
                .reduce(Decimal.zero) { $0 + $1.expectedAmount }
        )
    }

    /// Next scheduled income arrival date (expected, not yet confirmed),
    /// looking from `reference` forward within the target month.
    static func nextIncomeDate(_ income: [Transaction], after reference: Date = .now) -> Date? {
        income
            .filter { $0.incomeStatus == .expected && $0.date >= reference }
            .sorted { $0.date < $1.date }
            .first?
            .date
    }

    // MARK: - Category Breakdown

    static func categoryBreakdown(bills: [Transaction], expenses: [Transaction]) -> [CategoryBreakdown] {
        let all = bills + expenses
        let grouped = Dictionary(grouping: all) { $0.category }
        return grouped
            .map { key, txs in
                CategoryBreakdown(
                    category: key,
                    amount: roundCents(txs.reduce(Decimal.zero) { $0 + $1.amount })
                )
            }
            .sorted { $0.amount > $1.amount }
    }

    // MARK: - Savings

    static func actualSavingsThisMonth(
        _ transactions: [Transaction],
        month: Int,
        year: Int,
        calendar: Calendar = .current
    ) -> Decimal {
        let monthTransfers = transfers(transactions, month: month, year: year, calendar: calendar)
        return roundCents(
            monthTransfers
                .filter { tx in
                    if tx.savingsGoal != nil { return true }
                    if tx.category == .savingsTransfer { return true }
                    return false
                }
                .reduce(Decimal.zero) { $0 + $1.amount }
        )
    }

    static func plannedSavingsRemaining(planned: Decimal, actual: Decimal) -> Decimal {
        max(0, roundCents(planned - actual))
    }

    // MARK: - Averages

    static func averageMonthlySpending(
        _ transactions: [Transaction],
        lookbackMonths: Int = 3,
        reference: Date = .now,
        calendar: Calendar = .current
    ) -> Decimal {
        var totals: [Decimal] = []

        for offset in stride(from: -lookbackMonths, through: -1, by: 1) {
            guard let date = calendar.date(byAdding: .month, value: offset, to: reference) else { continue }
            let m = calendar.component(.month, from: date)
            let y = calendar.component(.year, from: date)

            let monthBills = bills(transactions, month: m, year: y)
            let monthExpenses = expenses(transactions, month: m, year: y)
            let total = billsTotal(monthBills) + expensesTotal(monthExpenses)
            if total > 0 { totals.append(total) }
        }

        guard !totals.isEmpty else { return 0 }
        let sum = totals.reduce(Decimal.zero, +)
        let average = NSDecimalNumber(decimal: sum)
            .dividing(by: NSDecimalNumber(value: totals.count))
            .decimalValue
        return roundCents(average)
    }

    // MARK: - Helpers

    private static func roundCents(_ value: Decimal) -> Decimal {
        var v = value
        var out = Decimal.zero
        NSDecimalRound(&out, &v, 2, .bankers)
        return out
    }
}
