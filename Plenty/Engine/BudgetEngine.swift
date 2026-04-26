//
//  BudgetEngine.swift
//  Plenty
//
//  Target path: Plenty/Engine/BudgetEngine.swift
//
//  The central calculation engine. Pure functions in, pure value types
//  out. Every view and every widget that shows the hero number goes
//  through this engine. If the number is wrong anywhere in the app,
//  it's wrong here.
//
//  Plenty's hero formula (refined from Left's per Phase 0 Decision 3.2):
//
//      spendable =
//          cashAccountsTotal
//        − billsRemaining (this month, unpaid)
//        − statementBalanceDueBeforeNextIncome (credit cards only)
//        − plannedSavingsRemaining
//
//  Key difference from Left: we subtract the credit card STATEMENT
//  balance due before the next income event, not the full outstanding
//  balance. Revolving balances the user is paying down over time stay
//  tracked as debt (on the Accounts tab and debt payoff view) but do
//  not enter the hero.
//
//  Falls back gracefully when data is missing:
//    • No statementBalance on a card   → no subtraction for that card
//    • No nextIncomeDate               → all statements due this month subtract
//    • No savingsGoals                 → no savings subtraction
//    • Goal with no monthlyContribution → contributes 0 to planned savings
//
//  Replaces the prior BudgetEngine. One change: the planned-savings
//  sum now treats `monthlyContribution` as optional, defaulting to 0.
//

import Foundation

enum BudgetEngine {

    // MARK: - Primary Entry Point

    /// Compute the full PlentySnapshot for a target month from raw data.
    static func calculate(
        accounts: [Account],
        transactions: [Transaction],
        savingsGoals: [SavingsGoal] = [],
        month: Int,
        year: Int,
        reference: Date = .now,
        calendar: Calendar = .current
    ) -> PlentySnapshot {

        // ---------- Cash position ----------
        let cashTotal = AccountDerivations.cashAccountsTotal(accounts)
        let ccDebt = AccountDerivations.creditCardDebt(accounts)
        let cashOnHand = AccountDerivations.cashOnHand(accounts)

        // ---------- This month's transactions ----------
        let monthBills    = TransactionProjections.bills(transactions, month: month, year: year)
        let monthExpenses = TransactionProjections.expenses(transactions, month: month, year: year)
        let monthIncome   = TransactionProjections.income(transactions, month: month, year: year)

        let billsTotal     = TransactionProjections.billsTotal(monthBills)
        let billsPaid      = TransactionProjections.billsPaid(monthBills)
        let billsRemaining = TransactionProjections.billsRemaining(monthBills)
        let expensesTotal  = TransactionProjections.expensesTotal(monthExpenses)

        // ---------- Income ----------
        let confirmedIncome = TransactionProjections.confirmedIncomeTotal(monthIncome)
        let expectedIncome  = TransactionProjections.expectedIncomeTotal(monthIncome)
        let totalIncome     = roundCents(confirmedIncome + expectedIncome)
        let nextIncomeDate  = TransactionProjections.nextIncomeDate(monthIncome, after: reference)

        // ---------- Statement balance due before next income ----------
        let statementDue = statementBalanceDueBeforeNextIncome(
            accounts: accounts,
            nextIncomeDate: nextIncomeDate,
            reference: reference,
            calendar: calendar
        )

        // ---------- Savings ----------
        let activeGoals = savingsGoals.filter { $0.isActive && !$0.isCompleted }
        let plannedSavings = roundCents(
            activeGoals.reduce(Decimal.zero) { $0 + ($1.monthlyContribution ?? 0) }
        )
        let actualSavings = TransactionProjections.actualSavingsThisMonth(
            transactions, month: month, year: year
        )
        let savingsRemaining = TransactionProjections.plannedSavingsRemaining(
            planned: plannedSavings, actual: actualSavings
        )

        // ---------- Spendable (the hero number) ----------
        let spendable = roundCents(
            cashTotal
            - billsRemaining
            - statementDue
            - savingsRemaining
        )

        // ---------- Breakdown + pace ----------
        let breakdown = TransactionProjections.categoryBreakdown(
            bills: monthBills, expenses: monthExpenses
        )

        let billsPaidCount = monthBills.filter(\.isPaid).count
        let confirmedCount = monthIncome.filter { $0.incomeStatus == .confirmed }.count

        let isCurrentMonth = Self.isCurrentMonth(
            month: month, year: year, reference: reference, calendar: calendar
        )
        let burn = BurnRate.smoothedDaily(
            transactions: transactions, reference: reference, calendar: calendar
        )
        let sustainable = BurnRate.sustainableDaily(
            left: spendable,
            isCurrentMonth: isCurrentMonth,
            reference: reference,
            calendar: calendar
        )

        return PlentySnapshot(
            spendable: spendable,
            cashOnHand: cashOnHand,
            cashAccountsTotal: cashTotal,
            creditCardDebt: ccDebt,
            statementDueBeforeNextIncome: statementDue,
            billsRemaining: billsRemaining,
            billsTotal: billsTotal,
            billsPaid: billsPaid,
            expensesThisMonth: expensesTotal,
            confirmedIncome: confirmedIncome,
            expectedIncome: expectedIncome,
            totalIncome: totalIncome,
            nextIncomeDate: nextIncomeDate,
            plannedSavingsThisMonth: plannedSavings,
            actualSavingsThisMonth: actualSavings,
            plannedSavingsRemaining: savingsRemaining,
            smoothedDailyBurn: burn,
            sustainableDailyBurn: sustainable,
            billsPaidCount: billsPaidCount,
            billsTotalCount: monthBills.count,
            incomeConfirmedCount: confirmedCount,
            incomeTotalCount: monthIncome.count,
            expensesByCategory: breakdown
        )
    }

    // MARK: - Statement Balance Logic (Phase 0 Decision 3.2)

    /// Sum of credit card statement balances that are due before the next
    /// income event. Only cards with BOTH statementBalance and statementDay
    /// set contribute; cards with missing data contribute zero (the user
    /// hasn't told us what's due, so we don't guess).
    ///
    /// If nextIncomeDate is nil (no more income expected this month), all
    /// cards with a statement due on or before the end of this month
    /// contribute. This matches the intuition that "if no income is
    /// coming, you need to cover everything due."
    static func statementBalanceDueBeforeNextIncome(
        accounts: [Account],
        nextIncomeDate: Date?,
        reference: Date = .now,
        calendar: Calendar = .current
    ) -> Decimal {
        let creditCards = AccountDerivations.creditAccounts(accounts)

        // Window end: either next income date, or end of current month.
        let windowEnd: Date = {
            if let nextIncomeDate { return nextIncomeDate }
            return calendar.endOfMonth(for: reference)
        }()

        var total: Decimal = 0

        for card in creditCards {
            guard let statementDay = card.statementDay,
                  let statementBalance = card.statementBalance,
                  statementBalance > 0
            else { continue }

            // Compute the next statementDay occurrence on or after reference.
            guard let nextStatement = nextOccurrence(
                ofDayOfMonth: statementDay,
                on: reference,
                calendar: calendar
            ) else { continue }

            if nextStatement <= windowEnd {
                total += statementBalance
            }
        }

        return roundCents(total)
    }

    /// Next date with the given day-of-month on or after `reference`.
    private static func nextOccurrence(
        ofDayOfMonth day: Int,
        on reference: Date,
        calendar: Calendar
    ) -> Date? {
        var comps = calendar.dateComponents([.year, .month], from: reference)
        comps.day = min(day, calendar.range(of: .day, in: .month, for: reference)?.count ?? day)
        guard let thisMonth = calendar.date(from: comps) else { return nil }

        if thisMonth >= calendar.startOfDay(for: reference) {
            return thisMonth
        }

        // This month's occurrence has passed; roll to next month.
        guard let nextMonthDate = calendar.date(byAdding: .month, value: 1, to: thisMonth),
              let nextMonthRange = calendar.range(of: .day, in: .month, for: nextMonthDate)
        else { return nil }

        var nextComps = calendar.dateComponents([.year, .month], from: nextMonthDate)
        nextComps.day = min(day, nextMonthRange.count)
        return calendar.date(from: nextComps)
    }

    // MARK: - Insights Helpers

    /// Average spendable over the last N months. Used by insights.
    static func averageSpendable(
        accounts: [Account],
        transactions: [Transaction],
        savingsGoals: [SavingsGoal] = [],
        lookbackMonths: Int = 3,
        reference: Date = .now,
        calendar: Calendar = .current
    ) -> Decimal {
        var totals: [Decimal] = []

        for offset in stride(from: -lookbackMonths, through: -1, by: 1) {
            guard let date = calendar.date(byAdding: .month, value: offset, to: reference) else { continue }
            let m = calendar.component(.month, from: date)
            let y = calendar.component(.year, from: date)

            let snapshot = calculate(
                accounts: accounts,
                transactions: transactions,
                savingsGoals: savingsGoals,
                month: m,
                year: y
            )
            if snapshot.totalIncome > 0 || snapshot.expensesThisMonth > 0 {
                totals.append(snapshot.spendable)
            }
        }

        guard !totals.isEmpty else { return 0 }
        let sum = totals.reduce(Decimal.zero, +)
        let average = NSDecimalNumber(decimal: sum)
            .dividing(by: NSDecimalNumber(value: totals.count))
            .decimalValue
        return roundCents(average)
    }

    // MARK: - Helpers

    static func isCurrentMonth(
        month: Int,
        year: Int,
        reference: Date = .now,
        calendar: Calendar = .current
    ) -> Bool {
        calendar.component(.month, from: reference) == month
            && calendar.component(.year, from: reference) == year
    }

    static func roundCents(_ value: Decimal) -> Decimal {
        var v = value
        var out = Decimal.zero
        NSDecimalRound(&out, &v, 2, .bankers)
        return out
    }
}
