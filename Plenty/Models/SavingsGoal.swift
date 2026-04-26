//
//  SavingsGoal.swift
//  Plenty
//
//  Target path: Plenty/Models/SavingsGoal.swift
//
//  A savings goal. Contributions are Transaction records of kind
//  .transfer that reference this goal; savedAmount aggregates across
//  those linked transfers (plus an optional legacy field for any
//  migrated data).
//
//  Port from Left with one change: `isShared: Bool` added for V1.1
//  sharing hook. Dormant in V1.0.
//

import Foundation
import SwiftData

@Model
final class SavingsGoal {

    // MARK: - Identity

    var id: UUID = UUID()

    // MARK: - Core

    var name: String = ""
    var goalTypeRaw: String = SavingsGoalType.custom.rawValue
    var targetAmount: Decimal = 0
    var monthlyContribution: Decimal = 0

    /// Legacy saved amount, preserved for migrated data. New contributions
    /// flow through linked Transaction records.
    var savedAmountLegacy: Decimal = 0

    var targetDate: Date?
    var emoji: String = "🎯"

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
        goalType: SavingsGoalType = .custom,
        targetAmount: Decimal,
        monthlyContribution: Decimal,
        targetDate: Date? = nil,
        emoji: String = "🎯"
    ) {
        self.id = UUID()
        self.name = name
        self.goalTypeRaw = goalType.rawValue
        self.targetAmount = targetAmount
        self.monthlyContribution = monthlyContribution
        self.targetDate = targetDate
        self.emoji = emoji
        self.createdAt = .now
        self.updatedAt = .now
    }

    // MARK: - Computed

    var goalType: SavingsGoalType {
        get { SavingsGoalType(rawValue: goalTypeRaw) ?? .custom }
        set { goalTypeRaw = newValue.rawValue }
    }

    /// Total saved: legacy amount plus every linked contribution.
    var savedAmount: Decimal {
        let fromContributions = (contributions ?? []).reduce(Decimal.zero) { $0 + $1.amount }
        return savedAmountLegacy + fromContributions
    }

    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return min(1.0, NSDecimalNumber(decimal: savedAmount)
            .dividing(by: NSDecimalNumber(decimal: targetAmount))
            .doubleValue)
    }

    var remaining: Decimal {
        max(0, targetAmount - savedAmount)
    }

    var estimatedMonthsLeft: Int? {
        guard monthlyContribution > 0, remaining > 0 else { return nil }
        let months = NSDecimalNumber(decimal: remaining)
            .dividing(by: NSDecimalNumber(decimal: monthlyContribution))
            .doubleValue
        return Int(ceil(months))
    }

    var projectedCompletionDate: Date? {
        guard let months = estimatedMonthsLeft else { return nil }
        return Calendar.current.date(byAdding: .month, value: months, to: .now)
    }

    // MARK: - Mutators

    func logContribution(amount: Decimal) {
        // Contributions flow through Transaction.transfer; this legacy
        // helper remains for tests and migrations. Real contributions
        // go through ModelContext insert of a Transaction.
        savedAmountLegacy += amount
        updatedAt = .now
        if savedAmount >= targetAmount && targetAmount > 0 {
            isCompleted = true
        }
    }

    func touch() { updatedAt = .now }
}
