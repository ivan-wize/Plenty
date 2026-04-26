//
//  SavingsGoal.swift
//  Plenty
//
//  Target path: Plenty/Models/SavingsGoal.swift
//
//  A savings goal. Contributions are Transaction records of kind
//  .transfer that reference this goal; contributedAmount aggregates
//  across those linked transfers (plus an optional legacy field for
//  any migrated data).
//
//  This file replaces the prior SavingsGoal to align the storage with
//  what the views were already calling for:
//
//    • `deadline: Date?`             (was `targetDate`)
//    • `monthlyContribution: Decimal?` (was non-optional `Decimal`)
//    • `note: String?`               (was missing)
//    • `contributedAmount`           (alias for `savedAmount`)
//
//  The init signature reflects what AddSavingsGoalSheet was already
//  constructing. Existing CloudKit data has no users yet (PRD
//  Section 1: "no existing users and no production data to migrate"),
//  so the rename of `targetDate` → `deadline` is safe.
//
//  Port from Left with the V1.1 sharing hook (`isShared`) preserved.
//

import Foundation
import SwiftData

@Model
final class SavingsGoal {

    // MARK: - Identity

    var id: UUID = UUID()

    // MARK: - Core

    var name: String = ""
    var goalTypeRaw: String = SavingsGoalType.general.rawValue
    var targetAmount: Decimal = 0

    /// Optional monthly savings target. When set and > 0, the budget
    /// engine subtracts the unfunded portion from the user's spendable
    /// number so they don't accidentally spend money they've committed
    /// to save. nil means "no monthly target" — the goal is real but
    /// the user hasn't paced it.
    var monthlyContribution: Decimal?

    /// Legacy saved amount, preserved for migrated data. New
    /// contributions flow through linked Transaction records.
    var savedAmountLegacy: Decimal = 0

    /// Optional target date by which the user wants to hit the goal.
    /// Plenty does not enforce or alarm on this date — it's display
    /// only and feeds the projected-completion comparison.
    var deadline: Date?

    var emoji: String = "🎯"
    var note: String?

    // MARK: - State

    var isActive: Bool = true
    var isCompleted: Bool = false
    var isArchived: Bool = false

    // MARK: - Sharing (V1.1 hook)

    /// Reserved for V1.1 household sharing. Dormant in V1.0.
    var isShared: Bool = false

    // MARK: - Relationships

    @Relationship(deleteRule: .nullify, inverse: \Transaction.savingsGoal)
    var contributions: [Transaction]?

    // MARK: - Metadata

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // MARK: - Init

    init(
        name: String,
        targetAmount: Decimal,
        goalType: SavingsGoalType = .general,
        deadline: Date? = nil,
        monthlyContribution: Decimal? = nil,
        note: String? = nil,
        emoji: String = "🎯"
    ) {
        self.id = UUID()
        self.name = name
        self.targetAmount = targetAmount
        self.goalTypeRaw = goalType.rawValue
        self.deadline = deadline
        self.monthlyContribution = monthlyContribution
        self.note = note
        self.emoji = emoji
        self.createdAt = .now
        self.updatedAt = .now
    }

    // MARK: - Computed

    var goalType: SavingsGoalType {
        get { SavingsGoalType(rawValue: goalTypeRaw) ?? .general }
        set { goalTypeRaw = newValue.rawValue }
    }

    /// Total saved: legacy amount plus every linked contribution.
    var savedAmount: Decimal {
        let fromContributions = (contributions ?? []).reduce(Decimal.zero) { $0 + $1.amount }
        return savedAmountLegacy + fromContributions
    }

    /// Synonym for savedAmount used by the contribution UI for clarity
    /// ("contributed $X of $Y" reads better than "saved $X of $Y" when
    /// the user is in the middle of logging a contribution).
    var contributedAmount: Decimal { savedAmount }

    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return min(1.0, NSDecimalNumber(decimal: savedAmount)
            .dividing(by: NSDecimalNumber(decimal: targetAmount))
            .doubleValue)
    }

    var remaining: Decimal {
        max(0, targetAmount - savedAmount)
    }

    /// Number of months to reach the goal at the current monthly
    /// contribution rate. Nil if no monthly target is set or already done.
    var estimatedMonthsLeft: Int? {
        guard let monthly = monthlyContribution, monthly > 0, remaining > 0 else { return nil }
        let months = NSDecimalNumber(decimal: remaining)
            .dividing(by: NSDecimalNumber(decimal: monthly))
            .doubleValue
        return Int(ceil(months))
    }

    var projectedCompletionDate: Date? {
        guard let months = estimatedMonthsLeft else { return nil }
        return Calendar.current.date(byAdding: .month, value: months, to: .now)
    }

    // MARK: - Mutators

    /// Legacy direct-credit method. Kept for tests and migrations only.
    /// Real contributions go through ModelContext.insert of a Transaction.
    func logContribution(amount: Decimal) {
        savedAmountLegacy += amount
        updatedAt = .now
        if savedAmount >= targetAmount && targetAmount > 0 {
            isCompleted = true
        }
    }

    func touch() { updatedAt = .now }
}
