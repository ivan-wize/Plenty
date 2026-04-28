//
//  PlentyEntry.swift
//  Plenty
//
//  Target path: PlentyWidget/PlentyEntry.swift
//  Widget target: PlentyWidget extension
//  Also linked: shared models (Account, Transaction, etc.), engine
//               (BudgetEngine, AccountDerivations, TransactionProjections,
//                PlentySnapshot), helpers (Decimal+Currency, Int+Ordinal,
//                Calendar+Helpers), ModelContainerFactory.
//
//  Phase 8 (v2): the timeline entry consumed by all widget families.
//
//  Hero now carries `monthlyBudgetRemaining` instead of `spendable`.
//  The v1 zone enum is gone — widgets derive state from the sign of
//  the number directly (positive / zero / negative). This matches the
//  in-app v2 hero treatment: sage when ≥ 0, terracotta when < 0.
//
//  When the data container can't open, `unavailable` is returned
//  with a flag set so widget views show a "open the app" message
//  instead of misleading zeros.
//

import Foundation
import WidgetKit

struct PlentyEntry: TimelineEntry {

    let date: Date

    // Hero (v2)
    let monthlyBudgetRemaining: Decimal

    // Context
    let cashOnHand: Decimal
    let sustainableDailyBurn: Decimal?
    let billsRemaining: Decimal
    let billsRemainingCount: Int
    let nextBillName: String?
    let nextBillAmount: Decimal?
    let nextBillDueDay: Int?
    let nextIncomeDate: Date?
    let expectedIncomeRemaining: Decimal

    // State
    let hasAnyData: Bool
    let isPlaceholder: Bool
    let isUnavailable: Bool

    // MARK: - Derived State Helpers

    var isOverBudget: Bool { monthlyBudgetRemaining < 0 }
    var isAtZero: Bool { monthlyBudgetRemaining == 0 }
    var isPositive: Bool { monthlyBudgetRemaining > 0 }

    // MARK: - Static Variants

    /// Widget gallery preview. Pleasant positive numbers.
    static let placeholder = PlentyEntry(
        date: .now,
        monthlyBudgetRemaining: 1840,
        cashOnHand: 4200,
        sustainableDailyBurn: 92,
        billsRemaining: 850,
        billsRemainingCount: 2,
        nextBillName: "Rent",
        nextBillAmount: 1200,
        nextBillDueDay: 1,
        nextIncomeDate: Calendar.current.date(byAdding: .day, value: 5, to: .now),
        expectedIncomeRemaining: 0,
        hasAnyData: true,
        isPlaceholder: true,
        isUnavailable: false
    )

    /// Returned when the data container can't open. Widget shows a
    /// muted "open the app" message instead of misleading zeros.
    static let unavailable = PlentyEntry(
        date: .now,
        monthlyBudgetRemaining: 0,
        cashOnHand: 0,
        sustainableDailyBurn: nil,
        billsRemaining: 0,
        billsRemainingCount: 0,
        nextBillName: nil,
        nextBillAmount: nil,
        nextBillDueDay: nil,
        nextIncomeDate: nil,
        expectedIncomeRemaining: 0,
        hasAnyData: false,
        isPlaceholder: false,
        isUnavailable: true
    )
}
