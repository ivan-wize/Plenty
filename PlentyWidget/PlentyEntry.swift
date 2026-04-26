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
//  TimelineEntry consumed by all widget families. Carries enough to
//  render every variant: small, medium, lock-screen circular,
//  rectangular, and inline.
//

import Foundation
import WidgetKit

struct PlentyEntry: TimelineEntry {

    let date: Date

    // Hero
    let spendable: Decimal
    let zone: PlentySnapshot.Zone

    // Context
    let cashOnHand: Decimal
    let sustainableDailyBurn: Decimal?
    let billsRemaining: Decimal
    let billsRemainingCount: Int
    let nextBillName: String?
    let nextBillAmount: Decimal?
    let nextBillDueDay: Int?
    let nextIncomeDate: Date?

    // State
    let hasAnyData: Bool
    let isPlaceholder: Bool
    let isUnavailable: Bool

    // MARK: - Static Variants

    /// Widget gallery preview. Pleasant safe-zone numbers.
    static let placeholder = PlentyEntry(
        date: .now,
        spendable: 1840,
        zone: .safe,
        cashOnHand: 4200,
        sustainableDailyBurn: 92,
        billsRemaining: 850,
        billsRemainingCount: 2,
        nextBillName: "Rent",
        nextBillAmount: 1200,
        nextBillDueDay: 1,
        nextIncomeDate: Calendar.current.date(byAdding: .day, value: 5, to: .now),
        hasAnyData: true,
        isPlaceholder: true,
        isUnavailable: false
    )

    /// Returned when the data container can't open. Widget shows a
    /// muted "open the app" message instead of misleading zeros.
    static let unavailable = PlentyEntry(
        date: .now,
        spendable: 0,
        zone: .empty,
        cashOnHand: 0,
        sustainableDailyBurn: nil,
        billsRemaining: 0,
        billsRemainingCount: 0,
        nextBillName: nil,
        nextBillAmount: nil,
        nextBillDueDay: nil,
        nextIncomeDate: nil,
        hasAnyData: false,
        isPlaceholder: false,
        isUnavailable: true
    )
}
