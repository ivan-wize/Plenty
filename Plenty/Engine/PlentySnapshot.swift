//
//  PlentySnapshot.swift
//  Plenty
//
//  Target path: Plenty/Engine/PlentySnapshot.swift
//
//  A point-in-time reading of the user's financial position, produced by
//  BudgetEngine.calculate(). Pure Sendable value type with no SwiftData
//  dependency so it flows through views, widgets, watch, and intents.
//
//  Renamed from Left's LeftSnapshot. The hero number field is renamed
//  from `left` to `spendable` to match Plenty's possession-leading voice
//  ("You have $1,840 spendable").
//
//  Hero formula per PRD §9.1 (refined by Phase 0 Decision 3.2):
//
//      spendable =
//        cashOnHand
//        − billsRemaining (this month, unpaid)
//        − statementBalanceDueBeforeNextIncome (credit cards only)
//        − plannedSavingsRemaining
//
//  NOTE: full credit card balance does not enter the hero. Revolving
//  balances are tracked as debt on the Accounts tab and powered by the
//  Debt Payoff view; they do not bleed into "what can I spend today."
//

import Foundation

// MARK: - PlentySnapshot

struct PlentySnapshot: Equatable, Sendable {

    // MARK: - The Hero Number

    /// What the user can safely spend right now.
    /// Formula: cashOnHand − billsRemaining − statementDueBeforeNextIncome − plannedSavingsRemaining.
    /// May be negative (over-committed).
    let spendable: Decimal

    // MARK: - Cash Position

    /// Cash accounts total minus credit card debt. "The real money you
    /// have." Note: uses FULL credit card balance here because cashOnHand
    /// is net worth-adjacent; the hero uses statement balance instead.
    let cashOnHand: Decimal

    /// Sum of all cash/checking/savings balances (positive).
    let cashAccountsTotal: Decimal

    /// Sum of all credit card balances owed (positive). This is the
    /// full outstanding balance, used by cashOnHand and Net Worth.
    let creditCardDebt: Decimal

    /// Sum of credit card statement balances due before the next income
    /// event (positive). This is what the hero subtracts. Falls back to
    /// zero when no cards have statementBalance set.
    let statementDueBeforeNextIncome: Decimal

    // MARK: - Commitments This Month

    /// Sum of unpaid bills' amounts this month.
    let billsRemaining: Decimal

    /// Sum of all bills this month, paid + unpaid.
    let billsTotal: Decimal

    /// Sum of bills already paid this month.
    let billsPaid: Decimal

    /// Actual spending this month (expenses, not bills). Not subtracted
    /// from spendable (it already reduced cash). Reported for context.
    let expensesThisMonth: Decimal

    // MARK: - Income This Month

    let confirmedIncome: Decimal
    let expectedIncome: Decimal
    let totalIncome: Decimal

    /// Date of the next scheduled income arrival. Nil if none this month
    /// or if all income is already confirmed.
    let nextIncomeDate: Date?

    // MARK: - Savings

    let plannedSavingsThisMonth: Decimal
    let actualSavingsThisMonth: Decimal

    /// Remaining planned savings; subtracted from spendable so the user
    /// doesn't spend money they've committed to save.
    let plannedSavingsRemaining: Decimal

    // MARK: - Pace

    /// 30-day rolling discretionary spend rate, per day.
    let smoothedDailyBurn: Decimal

    /// Per-day room to spend for the rest of the month: spendable ÷ days
    /// remaining. Nil when the target month isn't current, or when
    /// spendable is non-positive.
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

    // MARK: - Derived Health

    /// Allocation ratio for state classification, 0.0-1.0+.
    var allocationProgress: Double {
        let inflow = cashOnHand + totalIncome
        guard inflow > 0 else { return 0 }
        let committed = billsRemaining + statementDueBeforeNextIncome + plannedSavingsRemaining + expensesThisMonth
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
        expensesByCategory: []
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
