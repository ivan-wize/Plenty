//
//  BudgetEngine.swift
//  Plenty
//
//  Target path: Plenty/Engine/BudgetEngine.swift
//
//  Phase 1 (v2): produces `monthlyBudgetRemaining` alongside the v1
//  `spendable` number. Both fields populate the returned snapshot;
//  Plan-tab features (Outlook, Save, Trends, Net Worth detail) keep
//  reading the v1 fields, while v2 views (Overview, widgets after P8,
//  Watch after P8) read the new field.
//
//  v2 hero formula (PDS §2):
//
//      monthlyBudgetRemaining =
//          confirmedIncome (this month)
//        − billsTotal      (paid + unpaid this month)
//        − expensesThisMonth
//
//  v1 cash-based formula (retained for legacy consumers):
//
//      spendable =
//          cashAccountsTotal
//        − billsRemaining (this month, unpaid only)
//        − statementBalanceDueBeforeNextIncome (credit cards only)
//        − plannedSavingsRemaining
//
//  Falls back gracefully when data is missing:
//    • No statementBalance on a card   → no subtraction for that card
//    • No nextIncomeDate               → all statements due this month subtract
//    • No savingsGoals                 → no savings subtraction
//    • Goal with no monthlyContribution → contributes 0 to planned savings
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
        let cashTotal  = AccountDerivations.cashAccountsTotal(accounts)
        let ccDebt     = AccountDerivations.creditCardDebt(accounts)
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

        // ---------- v1 Hero: Spendable (cash-based) ----------
        let spendable = roundCents(
            cashTotal
            - billsRemaining
            - statementDue
            - savingsRemaining
        )

        // ---------- v2 Hero: Monthly Budget Remaining (envelope-based) ----------
        //
        // Per PDS §2: confirmedIncome − billsTotal − expensesTotal.
        // Note: bills enter at FULL total (paid + unpaid). Paying a
        // bill is bookkeeping; it doesn't change the math. Expected
        // (unconfirmed) income does NOT enter — it's surfaced via the
        // Overview projection line.
        let monthlyBudgetRemaining = roundCents(
            confirmedIncome - billsTotal - expensesTotal
        )

        // ---------- Breakdown + counts + pace ----------
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
            expensesByCategory: breakdown,
            monthlyBudgetRemaining: monthlyBudgetRemaining
        )
    }

    // MARK: - Statement Balance Logic

    /// Sum of credit card statement balances that are due before the
    /// next income event. Only cards with BOTH statementBalance and
    /// statementDay set contribute; cards with missing data contribute
    /// zero (the user hasn't told us what's due, so we don't guess).
    ///
    /// If nextIncomeDate is nil (no more income expected this month),
    /// all cards with a statement due on or before the end of this
    /// month contribute.
    static func statementBalanceDueBeforeNextIncome(
        accounts: [Account],
        nextIncomeDate: Date?,
        reference: Date = .now,
        calendar: Calendar = .current
    ) -> Decimal {
        let creditCards = accounts.filter { $0.kind == .credit && $0.isActive }

        var total = Decimal.zero
        for card in creditCards {
            guard
                let statementBalance = card.statementBalance,
                statementBalance > 0,
                let statementDay = card.statementDay
            else { continue }

            // The next due date for this card.
            guard let dueDate = nextStatementDueDate(
                day: statementDay,
                reference: reference,
                calendar: calendar
            ) else { continue }

            // Compare against next income (or end of month if none).
            let cutoff: Date
            if let nextIncomeDate = nextIncomeDate {
                cutoff = nextIncomeDate
            } else if let endOfMonth = calendar.endOfMonth(for: reference) {
                cutoff = endOfMonth
            } else {
                continue
            }

            if dueDate <= cutoff {
                total += statementBalance
            }
        }
        return roundCents(total)
    }

    /// Next occurrence of a given day-of-month, on or after `reference`.
    /// Wraps to next month when `reference`'s day is past the target.
    private static func nextStatementDueDate(
        day: Int,
        reference: Date,
        calendar: Calendar
    ) -> Date? {
        let comps = calendar.dateComponents([.year, .month, .day], from: reference)
        guard let currentDay = comps.day,
              let currentMonth = comps.month,
              let currentYear = comps.year
        else { return nil }

        var thisMonthComps = DateComponents()
        thisMonthComps.year = currentYear
        thisMonthComps.month = currentMonth
        thisMonthComps.day = day

        if day >= currentDay,
           let date = calendar.date(from: thisMonthComps) {
            return date
        }

        // Day already passed this month → next month, clamped to month length.
        guard let thisMonth = calendar.date(from: DateComponents(
            year: currentYear, month: currentMonth, day: 1)),
              let nextMonthDate = calendar.date(byAdding: .month, value: 1, to: thisMonth),
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

    /// Average monthly budget remaining (v2) over the last N months.
    /// Companion to `averageSpendable` for v2 insights surfaces.
    static func averageMonthlyBudgetRemaining(
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
                totals.append(snapshot.monthlyBudgetRemaining)
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

