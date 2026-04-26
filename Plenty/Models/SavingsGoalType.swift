//
//  SavingsGoalType.swift
//  Plenty
//
//  Target path: Plenty/Models/SavingsGoalType.swift
//
//  Goal type presets with smart default targets and suggested emojis.
//  Port from Left unchanged.
//

import Foundation

enum SavingsGoalType: String, Codable, CaseIterable, Identifiable, Sendable {
    case emergencyFund
    case vacation
    case downPayment
    case newCar
    case payOffDebt
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .emergencyFund: return "Emergency Fund"
        case .vacation:      return "Vacation"
        case .downPayment:   return "Down Payment"
        case .newCar:        return "New Car"
        case .payOffDebt:    return "Pay Off Debt"
        case .custom:        return "Custom"
        }
    }

    var emoji: String {
        switch self {
        case .emergencyFund: return "🛡️"
        case .vacation:      return "✈️"
        case .downPayment:   return "🏠"
        case .newCar:        return "🚗"
        case .payOffDebt:    return "💳"
        case .custom:        return "🎯"
        }
    }

    var icon: String {
        switch self {
        case .emergencyFund: return "shield.fill"
        case .vacation:      return "airplane"
        case .downPayment:   return "house.fill"
        case .newCar:        return "car.fill"
        case .payOffDebt:    return "creditcard.fill"
        case .custom:        return "star.fill"
        }
    }

    /// Static suggested target, or nil if auto-calculated from user data.
    var suggestedTarget: Decimal? {
        switch self {
        case .emergencyFund: return nil        // 3x avg monthly expenses
        case .vacation:      return 3_000
        case .downPayment:   return 60_000     // 20% of $300K median home
        case .newCar:        return 10_000
        case .payOffDebt:    return nil        // Sum of tracked debt
        case .custom:        return nil
        }
    }

    var targetDescription: String? {
        switch self {
        case .emergencyFund: return "3× your average monthly expenses"
        case .vacation:      return nil
        case .downPayment:   return "20% of median home price"
        case .newCar:        return nil
        case .payOffDebt:    return "Sum of your tracked debt"
        case .custom:        return nil
        }
    }

    func calculatedTarget(averageMonthlyExpenses: Decimal, totalDebt: Decimal) -> Decimal? {
        switch self {
        case .emergencyFund:
            let target = averageMonthlyExpenses * 3
            return target > 0 ? target : 5_000
        case .payOffDebt:
            return totalDebt > 0 ? totalDebt : nil
        default:
            return suggestedTarget
        }
    }

    // MARK: - Contribution Suggestions

    struct ContributionTier: Sendable {
        let label: String
        let amount: Decimal
        let monthsToGoal: Int?
    }

    /// Three contribution tiers keyed off the user's average spendable.
    static func suggestedContributions(
        averageSpendable: Decimal,
        targetAmount: Decimal
    ) -> [ContributionTier] {
        guard averageSpendable > 0, targetAmount > 0 else { return [] }

        let tiers: [(String, Decimal)] = [
            ("Conservative", averageSpendable * (Decimal(1) / Decimal(10))),
            ("Balanced",     averageSpendable * (Decimal(2) / Decimal(10))),
            ("Aggressive",   averageSpendable * (Decimal(3) / Decimal(10))),
        ]

        return tiers.map { label, amount in
            let rounded = roundToWholeDollars(amount)
            let clamped = max(rounded, 10)
            let months: Int? = clamped > 0
                ? Int(ceil(NSDecimalNumber(decimal: targetAmount / clamped).doubleValue))
                : nil

            return ContributionTier(label: label, amount: clamped, monthsToGoal: months)
        }
    }

    // MARK: - Helpers

    private static func roundToWholeDollars(_ value: Decimal) -> Decimal {
        var v = value
        var out = Decimal.zero
        NSDecimalRound(&out, &v, 0, .bankers)
        return out
    }
}
