//
//  PlentySnapshot.swift
//  Plenty
//
//  Target path: Plenty/Engine/PlentySnapshot.swift
//
//  Phase 1 (v2): adds `monthlyBudgetRemaining` (the new hero number)
//  alongside the v1 fields used by Plan-tab features.
//
//  A point-in-time reading of the user's financial position, produced
//  by BudgetEngine.calculate(). Pure Sendable value type with no
//  SwiftData dependency so it flows through views, widgets, watch, and
//  intents.
//
//  v2 hero formula (PDS §2):
//
//      monthlyBudgetRemaining =
//          confirmedIncome (this month)
//        − billsTotal      (paid + unpaid this month)
//        − expensesThisMonth
//
//  Negative when over-budget. Early in a month, before paychecks have
//  confirmed, this can read negative. The Overview tab shows a small
//  secondary line ("+ $X expected this month") so users see the
//  forward shape.
//
//  All v1 fields stay populated. Plan-tab features (Outlook, Save,
//  Trends, Net Worth detail) still consume `spendable`, `cashOnHand`,
//  `statementDueBeforeNextIncome`, savings totals, and burn rates. v2
//  views read `monthlyBudgetRemaining` and the v2 alias accessors at
//  the bottom of this file.
//
//  Naming aliases on this struct (`confirmedIncomeThisMonth`,
//  `expectedIncomeRemaining`, `billsThisMonth`) are zero-cost computed
//  properties; they exist purely to make v2 call sites read clearly
//  without forcing the underlying field rename.
//

import Foundation

// MARK: - PlentySnapshot

struct PlentySnapshot: Equatable, Sendable {

    // MARK: - The Hero Number (v2)

    /// **The Overview hero in v2.** Money still in the user's monthly
    /// envelope: confirmed income minus all bills (paid + unpaid)
    /// minus expenses logged this month.
    ///
    /// May be negative (typical early in a month before paychecks
    /// confirm). The Overview's projection line shows expected income
    /// still to come, providing forward context.
    let monthlyBudgetRemaining: Decimal

    // MARK: - Legacy Hero (v1, retained for Plan-tab Pro features)

    /// v1 cash-based "spendable" number. Retained because Plan-tab
    /// features (Outlook projections, Net Worth detail) and existing
    /// widgets / Watch / intents still consume it. New v2 view code
    /// should prefer `monthlyBudgetRemaining`.
    let spendable: Decimal

    // MARK: - Cash Position

    /// Cash accounts total minus credit card debt. "The real money you
    /// have." Used by Plan-tab Net Worth surfaces.
    let cashOnHand: Decimal

    /// Sum of all cash/checking/savings balances (positive).
    let cashAccountsTotal: Decimal

    /// Sum of all credit card balances owed (positive). Full
    /// outstanding balance (not statement balance).
    let creditCardDebt: Decimal

    /// Sum of credit card statement balances due before the next
    /// income event. Powers Outlook's near-term cash flow.
    let statementDueBeforeNextIncome: Decimal

    // MARK: - Commitments This Month

    /// Sum of unpaid bills' amounts this month.
    let billsRemaining: Decimal

    /// Sum of all bills this month, paid + unpaid. **This is what v2's
    /// hero formula subtracts.** Surfaced as `billsThisMonth` for
    /// readability in v2 code.
    let billsTotal: Decimal

    /// Sum of bills already paid this month.
    let billsPaid: Decimal

    /// Actual spending this month (expenses, not bills). v2's hero
    /// formula subtracts this directly.
    let expensesThisMonth: Decimal

    // MARK: - Income This Month

    /// Confirmed (received) income this month. v2's hero formula adds
    /// this. Surfaced as `confirmedIncomeThisMonth` in v2 code.
    let confirmedIncome: Decimal

    /// Expected (not yet confirmed) income this month. Surfaced as
    /// `expectedIncomeRemaining` since confirmed entries flip out of
    /// `.expected` status. Powers the Overview projection line.
    let expectedIncome: Decimal

    /// Confirmed + expected.
    let totalIncome: Decimal

    /// Date of the next scheduled income arrival. Nil if none this
    /// month or if all income is already confirmed.
    let nextIncomeDate: Date?

    // MARK: - Savings

    let plannedSavingsThisMonth: Decimal
    let actualSavingsThisMonth: Decimal

    /// Remaining planned savings; subtracted from v1 `spendable` so the
    /// user doesn't dip into committed savings. **Not** subtracted
    /// from `monthlyBudgetRemaining` in v2 (savings goals are tracked
    /// in Plan/Save, not in the envelope math).
    let plannedSavingsRemaining: Decimal

    // MARK: - Pace

    /// 30-day rolling discretionary spend rate, per day.
    let smoothedDailyBurn: Decimal

    /// Per-day room to spend for the rest of the month based on v1
    /// `spendable`. Nil when not the current month, or when spendable
    /// is non-positive. Plan-tab feature; v2 Overview uses
    /// `BurnRate.monthEndProjection` for its own optional forecast.
    let sustainableDailyBurn: Decimal?

    // MARK: - Counts

    let billsPaidCount: Int
    let billsTotalCount: Int
    let incomeConfirmedCount: Int
    let incomeTotalCount: Int

    var allIncomeConfirmed: Bool {
        incomeTotalCount > 0 && incomeConfirmedCount == incomeTotalCount
    }

    var allBillsPaid: Bool {
        billsTotalCount > 0 && billsPaidCount == billsTotalCount
    }

    // MARK: - Breakdown

    let expensesByCategory: [CategoryBreakdown]

    // MARK: - v2 Naming Aliases

    /// v2 alias for `confirmedIncome`. Reads as: "confirmed income
    /// for this month."
    var confirmedIncomeThisMonth: Decimal { confirmedIncome }

    /// v2 alias for `expectedIncome`. Reads as: "income still expected
    /// to confirm this month." Confirmed entries flip out of
    /// `.expected` status, so this naturally shrinks as paychecks land.
    var expectedIncomeRemaining: Decimal { expectedIncome }

    /// v2 alias for `billsTotal`. Reads as: "bills for this month
    /// (paid + unpaid)."
    var billsThisMonth: Decimal { billsTotal }

    /// True when the v2 hero is below zero. Drives Overview's
    /// terracotta hero color.
    var monthlyBudgetIsNegative: Bool { monthlyBudgetRemaining < 0 }

    // MARK: - Derived Health (v1)

    /// Allocation ratio for v1 zone classification, 0.0-1.0+.
    var allocationProgress: Double {
        let inflow = cashOnHand + totalIncome
        guard inflow > 0 else { return 0 }
        let committed = billsRemaining + statementDueBeforeNextIncome
            + plannedSavingsRemaining + expensesThisMonth
        return NSDecimalNumber(decimal: committed)
            .dividing(by: NSDecimalNumber(decimal: inflow))
            .doubleValue
    }

    // MARK: - Zone & Pace

    enum Zone: Equatable, Sendable {
        /// No income data yet. Dim the hero; don't alarm.
        case empty
        /// Comfortable margin.
        case safe
        /// Getting tight. Either allocation ≥ 85% or pace is elevated.
        case warning
        /// Over-committed (spendable < 0).
        case over
    }

    enum Pace: Equatable, Sendable {
        case notApplicable
        case onTrack
        case warning
        case over
    }

    var pace: Pace {
        guard let sustainable = sustainableDailyBurn, sustainable > 0 else {
            return .notApplicable
        }
        if smoothedDailyBurn <= sustainable { return .onTrack }

        let warningCeiling = NSDecimalNumber(decimal: sustainable)
            .multiplying(by: NSDecimalNumber(value: 1.15))
            .decimalValue
        return smoothedDailyBurn <= warningCeiling ? .warning : .over
    }

    var zone: Zone {
        if totalIncome == 0 && cashOnHand == 0 { return .empty }
        if spendable < 0 { return .over }
        if pace == .over { return .warning }
        if allocationProgress >= 0.85 || pace == .warning { return .warning }
        return .safe
    }

    // MARK: - Init
    //
    // `monthlyBudgetRemaining` defaults to 0 so existing call sites
    // (PlentySnapshot.empty, SwiftUI preview helpers, widget
    // placeholders) compile without modification. BudgetEngine.calculate
    // always passes the real value.

    init(
        spendable: Decimal,
        cashOnHand: Decimal,
        cashAccountsTotal: Decimal,
        creditCardDebt: Decimal,
        statementDueBeforeNextIncome: Decimal,
        billsRemaining: Decimal,
        billsTotal: Decimal,
        billsPaid: Decimal,
        expensesThisMonth: Decimal,
        confirmedIncome: Decimal,
        expectedIncome: Decimal,
        totalIncome: Decimal,
        nextIncomeDate: Date?,
        plannedSavingsThisMonth: Decimal,
        actualSavingsThisMonth: Decimal,
        plannedSavingsRemaining: Decimal,
        smoothedDailyBurn: Decimal,
        sustainableDailyBurn: Decimal?,
        billsPaidCount: Int,
        billsTotalCount: Int,
        incomeConfirmedCount: Int,
        incomeTotalCount: Int,
        expensesByCategory: [CategoryBreakdown],
        monthlyBudgetRemaining: Decimal = 0
    ) {
        self.spendable = spendable
        self.cashOnHand = cashOnHand
        self.cashAccountsTotal = cashAccountsTotal
        self.creditCardDebt = creditCardDebt
        self.statementDueBeforeNextIncome = statementDueBeforeNextIncome
        self.billsRemaining = billsRemaining
        self.billsTotal = billsTotal
        self.billsPaid = billsPaid
        self.expensesThisMonth = expensesThisMonth
        self.confirmedIncome = confirmedIncome
        self.expectedIncome = expectedIncome
        self.totalIncome = totalIncome
        self.nextIncomeDate = nextIncomeDate
        self.plannedSavingsThisMonth = plannedSavingsThisMonth
        self.actualSavingsThisMonth = actualSavingsThisMonth
        self.plannedSavingsRemaining = plannedSavingsRemaining
        self.smoothedDailyBurn = smoothedDailyBurn
        self.sustainableDailyBurn = sustainableDailyBurn
        self.billsPaidCount = billsPaidCount
        self.billsTotalCount = billsTotalCount
        self.incomeConfirmedCount = incomeConfirmedCount
        self.incomeTotalCount = incomeTotalCount
        self.expensesByCategory = expensesByCategory
        self.monthlyBudgetRemaining = monthlyBudgetRemaining
    }

    // MARK: - Empty

    static let empty = PlentySnapshot(
        spendable: 0,
        cashOnHand: 0,
        cashAccountsTotal: 0,
        creditCardDebt: 0,
        statementDueBeforeNextIncome: 0,
        billsRemaining: 0,
        billsTotal: 0,
        billsPaid: 0,
        expensesThisMonth: 0,
        confirmedIncome: 0,
        expectedIncome: 0,
        totalIncome: 0,
        nextIncomeDate: nil,
        plannedSavingsThisMonth: 0,
        actualSavingsThisMonth: 0,
        plannedSavingsRemaining: 0,
        smoothedDailyBurn: 0,
        sustainableDailyBurn: nil,
        billsPaidCount: 0,
        billsTotalCount: 0,
        incomeConfirmedCount: 0,
        incomeTotalCount: 0,
        expensesByCategory: [],
        monthlyBudgetRemaining: 0
    )
}

// MARK: - CategoryBreakdown

struct CategoryBreakdown: Equatable, Sendable, Identifiable {
    let category: TransactionCategory?  // nil = uncategorized
    let amount: Decimal

    var id: String { category?.rawValue ?? "__uncategorized" }

    var displayName: String {
        category?.displayName ?? "Uncategorized"
    }

    var iconName: String {
        category?.iconName ?? "questionmark.circle"
    }
}
