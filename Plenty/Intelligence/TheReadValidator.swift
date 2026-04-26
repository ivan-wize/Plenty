//
//  TheReadValidator.swift
//  Plenty
//
//  Target path: Plenty/Features/Home/TheRead/TheReadValidator.swift
//
//  Cross-checks AI-generated Reads against the snapshot before display.
//  Per Phase 0 Decision 3.3:
//
//      "Validator cross-checks amounts within $1, dates against snapshot."
//
//  If validation fails, TheReadEngine retries once with a fresh prompt;
//  if that fails too, it falls back to deterministic templates. Either
//  way, the user never sees a wrong number.
//

import Foundation

enum TheReadValidator {

    /// Result of validation.
    enum Result: Equatable, Sendable {
        case valid
        case amountMismatch(claimed: Decimal, nearestActual: Decimal?)
        case dateMismatch(claimed: Date)
    }

    // MARK: - Public

    /// Validate that an amount and/or date claimed by an AI-generated
    /// Read body matches values present in the snapshot.
    ///
    /// - Parameters:
    ///   - claimedAmount: The dollar value the AI mentioned in the body,
    ///     or nil if the body mentions no amount.
    ///   - claimedDate: The date the AI referenced (e.g., next paycheck),
    ///     or nil.
    ///   - snapshot: The PlentySnapshot the AI was generating against.
    /// - Returns: `.valid` if both checks pass (or were not applicable),
    ///   otherwise the specific mismatch.
    static func validate(
        claimedAmount: Decimal?,
        claimedDate: Date?,
        against snapshot: PlentySnapshot,
        calendar: Calendar = .current
    ) -> Result {

        if let amount = claimedAmount {
            let actuals = candidateAmounts(snapshot: snapshot)
            let nearest = nearestAmount(to: amount, in: actuals)
            let withinTolerance = nearest.map { abs(($0 - amount).asDoubleValue) <= 1.0 } ?? false
            if !withinTolerance {
                return .amountMismatch(claimed: amount, nearestActual: nearest)
            }
        }

        if let date = claimedDate {
            let actuals = candidateDates(snapshot: snapshot)
            let withinDay = actuals.contains { calendar.isDate($0, inSameDayAs: date) }
            if !withinDay {
                return .dateMismatch(claimed: date)
            }
        }

        return .valid
    }

    // MARK: - Snapshot Candidate Sets

    /// Every dollar value the snapshot exposes that an AI Read might
    /// reasonably reference. The validator accepts any of these within
    /// $1 tolerance; anything else is rejected.
    private static func candidateAmounts(snapshot: PlentySnapshot) -> [Decimal] {
        var amounts: [Decimal] = [
            snapshot.spendable,
            snapshot.cashOnHand,
            snapshot.cashAccountsTotal,
            snapshot.creditCardDebt,
            snapshot.statementDueBeforeNextIncome,
            snapshot.billsRemaining,
            snapshot.billsTotal,
            snapshot.billsPaid,
            snapshot.expensesThisMonth,
            snapshot.confirmedIncome,
            snapshot.expectedIncome,
            snapshot.totalIncome,
            snapshot.plannedSavingsThisMonth,
            snapshot.actualSavingsThisMonth,
            snapshot.plannedSavingsRemaining,
        ]

        // Per-category breakdown amounts are also fair game.
        amounts.append(contentsOf: snapshot.expensesByCategory.map(\.amount))

        // And both burn rate values as daily numbers.
        amounts.append(snapshot.smoothedDailyBurn)
        if let sustainable = snapshot.sustainableDailyBurn {
            amounts.append(sustainable)
        }

        // Filter zero values to keep the candidate set tight; an AI
        // reference to "$0" should match because we surface it.
        return amounts
    }

    /// Every date the snapshot exposes. Currently just the next income
    /// date, though future Read types may add more.
    private static func candidateDates(snapshot: PlentySnapshot) -> [Date] {
        [snapshot.nextIncomeDate].compactMap { $0 }
    }

    // MARK: - Helpers

    private static func nearestAmount(to target: Decimal, in candidates: [Decimal]) -> Decimal? {
        candidates.min(by: { abs(($0 - target).asDoubleValue) < abs(($1 - target).asDoubleValue) })
    }
}

// MARK: - Decimal Helper

private extension Decimal {
    var asDoubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}
