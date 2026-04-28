//
//  BurnRate.swift
//  Plenty
//
//  Target path: Plenty/Engine/BurnRate.swift
//
//  Phase 1 (v2): + `monthEndProjection(...)` for the Overview tab's
//  optional "On pace to spend $X by month end." forecast line (PDS §5).
//
//  Existing behaviors retained:
//    • smoothedDaily(...)    — 30-day rolling discretionary burn
//    • sustainableDaily(...) — per-day room for the rest of the month
//                              based on v1 `spendable`
//
//  These continue to power the v1 pace classification consumed by The
//  Read engine and Plan-tab features.
//

import Foundation

enum BurnRate {

    // MARK: - Smoothed 30-day burn

    /// Sum of expense transactions over the last 30 days, divided by 30.
    /// Only expenses (not bills, not transfers). Returns 0 for a user
    /// with no history in the window.
    static func smoothedDaily(
        transactions: [Transaction],
        reference: Date = .now,
        calendar: Calendar = .current
    ) -> Decimal {
        guard let start = calendar.date(byAdding: .day, value: -30, to: reference) else {
            return 0
        }

        let window = transactions.filter {
            $0.kind == .expense && $0.date >= start && $0.date <= reference
        }
        let total = window.reduce(Decimal.zero) { $0 + $1.amount }
        return roundCents(
            NSDecimalNumber(decimal: total)
                .dividing(by: NSDecimalNumber(value: 30))
                .decimalValue
        )
    }

    // MARK: - Sustainable daily rate (v1)

    /// Per-day room to spend for the remainder of the current month.
    /// Returns nil when not the current month, or when spendable is
    /// non-positive. Drives v1 pace classification.
    static func sustainableDaily(
        left spendable: Decimal,
        isCurrentMonth: Bool,
        reference: Date = .now,
        calendar: Calendar = .current
    ) -> Decimal? {
        guard isCurrentMonth, spendable > 0 else { return nil }

        guard
            let monthEnd = calendar.endOfMonth(for: reference) as Date?,
            let daysRemaining = calendar.dateComponents([.day], from: reference, to: monthEnd).day,
            daysRemaining > 0
        else { return nil }

        return roundCents(
            NSDecimalNumber(decimal: spendable)
                .dividing(by: NSDecimalNumber(value: daysRemaining + 1))
                .decimalValue
        )
    }

    // MARK: - Month-End Projection (v2)

    /// Projected total expenses (variable spending only — bills are
    /// excluded) by the end of the current month, given the current
    /// expense total and the smoothed daily burn rate.
    ///
    /// Returns nil when:
    ///   • The reference date isn't in the same calendar month as the
    ///     month being projected (caller should only call for the
    ///     current month).
    ///   • It's too early in the month for a stable signal — default
    ///     `minimumDaysForSignal: 5` matches PDS §5: "Returns nil
    ///     before day 5 of the month (insufficient signal)."
    ///   • The smoothed daily burn is essentially zero (no signal yet).
    ///
    /// Output is `currentExpenses + smoothedDailyBurn × daysRemaining`,
    /// rounded to cents.
    static func monthEndProjection(
        currentExpenses: Decimal,
        smoothedDailyBurn: Decimal,
        reference: Date = .now,
        calendar: Calendar = .current,
        minimumDaysForSignal: Int = 5,
        minimumDailyBurnSignal: Decimal = 1
    ) -> Decimal? {
        let dayOfMonth = calendar.component(.day, from: reference)
        guard dayOfMonth >= minimumDaysForSignal else { return nil }

        guard smoothedDailyBurn > minimumDailyBurnSignal else { return nil }

        guard let monthRange = calendar.range(of: .day, in: .month, for: reference) else {
            return nil
        }

        let daysInMonth = monthRange.count
        let daysRemaining = max(0, daysInMonth - dayOfMonth)

        let projectedAdditional = smoothedDailyBurn * Decimal(daysRemaining)
        return roundCents(currentExpenses + projectedAdditional)
    }

    // MARK: - Helpers

    private static func roundCents(_ value: Decimal) -> Decimal {
        var v = value
        var out = Decimal.zero
        NSDecimalRound(&out, &v, 2, .bankers)
        return out
    }
}
