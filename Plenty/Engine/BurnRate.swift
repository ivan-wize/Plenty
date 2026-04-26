//
//  BurnRate.swift
//  Plenty
//
//  Target path: Plenty/Engine/BurnRate.swift
//
//  30-day rolling discretionary burn rate. Used by PlentySnapshot's pace
//  classification to flag "you're spending faster than sustainable."
//
//  Port from Left.
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

    // MARK: - Sustainable daily rate

    /// Per-day room to spend for the remainder of the current month.
    /// Returns nil when not the current month, or when spendable is
    /// non-positive.
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

    // MARK: - Helpers

    private static func roundCents(_ value: Decimal) -> Decimal {
        var v = value
        var out = Decimal.zero
        NSDecimalRound(&out, &v, 2, .bankers)
        return out
    }
}
