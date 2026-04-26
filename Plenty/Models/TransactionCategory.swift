//
//  TransactionCategory.swift
//  Plenty
//
//  Target path: Plenty/Models/TransactionCategory.swift
//
//  21 categories total: 10 expense buckets, 6 income, 4 transfer, plus
//  `other` as the catchall. Port from Left v2 (the 10-category trim
//  that dropped the long tail of low-frequency expense buckets).
//
//  Stored as a raw String on Transaction for CloudKit compatibility.
//  Unknown values (e.g., from a legacy export that had "pets") fall
//  back to nil at decode time; callers render nil as "Uncategorized."
//

import Foundation
import SwiftUI

enum TransactionCategory: String, Codable, CaseIterable, Identifiable, Sendable {

    // MARK: - Expense categories (10)

    case groceries
    case dining
    case transportation
    case shopping
    case entertainment
    case health
    case housing
    case utilities
    case subscriptions

    // MARK: - Income categories (6)

    case paycheck
    case bonus
    case refund
    case gift
    case interest
    case sideIncome

    // MARK: - Transfer categories (4)

    case savingsTransfer
    case creditCardPayment
    case loanPayment
    case investmentContribution

    // MARK: - Catchall

    case other

    var id: String { rawValue }

    // MARK: - Classification

    enum Scope: Sendable { case expense, income, transfer }

    /// The primary scope this category belongs to. Drives picker filtering.
    var primaryScope: Scope {
        switch self {
        case .paycheck, .bonus, .refund, .gift, .interest, .sideIncome:
            return .income
        case .savingsTransfer, .creditCardPayment, .loanPayment, .investmentContribution:
            return .transfer
        default:
            return .expense
        }
    }

    var isExpense: Bool  { primaryScope == .expense }
    var isIncome: Bool   { primaryScope == .income }
    var isTransfer: Bool { primaryScope == .transfer }

    // MARK: - Display

    var displayName: String {
        switch self {
        case .groceries:              return "Groceries"
        case .dining:                 return "Dining"
        case .transportation:         return "Transportation"
        case .shopping:               return "Shopping"
        case .entertainment:          return "Entertainment"
        case .health:                 return "Health"
        case .housing:                return "Housing"
        case .utilities:              return "Utilities"
        case .subscriptions:          return "Subscriptions"
        case .paycheck:               return "Paycheck"
        case .bonus:                  return "Bonus"
        case .refund:                 return "Refund"
        case .gift:                   return "Gift"
        case .interest:               return "Interest"
        case .sideIncome:             return "Side Income"
        case .savingsTransfer:        return "Savings"
        case .creditCardPayment:      return "Credit Card Payment"
        case .loanPayment:            return "Loan Payment"
        case .investmentContribution: return "Investment"
        case .other:                  return "Other"
        }
    }

    var iconName: String {
        switch self {
        case .groceries:              return "cart.fill"
        case .dining:                 return "fork.knife"
        case .transportation:         return "car.fill"
        case .shopping:               return "bag.fill"
        case .entertainment:          return "film.fill"
        case .health:                 return "cross.case.fill"
        case .housing:                return "house.fill"
        case .utilities:              return "bolt.fill"
        case .subscriptions:          return "arrow.triangle.2.circlepath"
        case .paycheck:               return "banknote.fill"
        case .bonus:                  return "star.fill"
        case .refund:                 return "arrow.uturn.left.circle.fill"
        case .gift:                   return "gift.fill"
        case .interest:               return "percent"
        case .sideIncome:             return "briefcase.fill"
        case .savingsTransfer:        return "dollarsign.bank.building.fill"
        case .creditCardPayment:      return "creditcard.fill"
        case .loanPayment:            return "doc.text.fill"
        case .investmentContribution: return "chart.line.uptrend.xyaxis"
        case .other:                  return "square.grid.2x2.fill"
        }
    }

    // MARK: - Tint
    //
    // All categories render in a single neutral tint on their icon chip
    // (soft sage at Theme.Opacity.soft) per PRD §4.3 restraint. Category
    // differentiation comes from the icon glyph, not color. Amber and
    // terracotta are reserved for state; do NOT use them here.

    var tint: Color { Theme.sage }

    // MARK: - Convenience Sets

    static var expenseCases:  [TransactionCategory] { allCases.filter(\.isExpense)  }
    static var incomeCases:   [TransactionCategory] { allCases.filter(\.isIncome)   }
    static var transferCases: [TransactionCategory] { allCases.filter(\.isTransfer) }
}
