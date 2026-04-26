//
//  AccountCategory.swift
//  Plenty
//
//  Target path: Plenty/Models/AccountCategory.swift
//
//  The type of a financial account. 12 specific categories grouped into
//  4 top-level kinds (cash, credit, investment, loan). Each kind knows
//  whether it represents an asset or a liability and whether it can be
//  spent from.
//
//  Port from Left with one brand change: tint colors now resolve through
//  Theme rather than raw `.green` / `.blue`. Category tints on icon
//  chips remain neutral (soft sage per PRD §4.3 restraint); this enum's
//  `accentColor` is used only when a category needs a distinguishing
//  accent, which is rare in Plenty.
//

import Foundation
import SwiftUI

// MARK: - Account Category

enum AccountCategory: String, Codable, CaseIterable, Identifiable, Sendable {

    // Assets
    case debit
    case savings
    case investment
    case property
    case otherAsset

    // Liabilities
    case creditCard
    case studentLoan
    case mortgage
    case autoLoan
    case personalLoan
    case medicalDebt
    case otherDebt

    var id: String { rawValue }

    // MARK: - Top-Level Kind

    enum Kind: String, Codable, CaseIterable, Identifiable, Sendable {
        case cash
        case credit
        case investment
        case loan

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .cash:       return "Cash"
            case .credit:     return "Credit"
            case .investment: return "Investment"
            case .loan:       return "Loan"
            }
        }

        var pluralDisplayName: String {
            switch self {
            case .cash:       return "Cash Accounts"
            case .credit:     return "Credit Cards"
            case .investment: return "Investments"
            case .loan:       return "Loans"
            }
        }

        /// Whether balances of this kind count as assets (positive).
        var isAsset: Bool {
            switch self {
            case .cash, .investment: return true
            case .credit, .loan:     return false
            }
        }

        /// Whether this kind can be spent from directly.
        var isSpendable: Bool {
            switch self {
            case .cash, .credit:     return true
            case .investment, .loan: return false
            }
        }

        /// Whether balances of this kind participate in cash-on-hand.
        /// Credit card balances subtract from cash on hand; investments
        /// and loans do not.
        var affectsCashOnHand: Bool {
            switch self {
            case .cash, .credit:     return true
            case .investment, .loan: return false
            }
        }
    }

    var kind: Kind {
        switch self {
        case .debit, .savings:
            return .cash
        case .creditCard:
            return .credit
        case .investment, .property, .otherAsset:
            return .investment
        case .studentLoan, .mortgage, .autoLoan, .personalLoan, .medicalDebt, .otherDebt:
            return .loan
        }
    }

    var isAsset: Bool { kind.isAsset }

    // MARK: - Display

    var displayName: String {
        switch self {
        case .debit:        return "Checking"
        case .savings:      return "Savings"
        case .investment:   return "Investment"
        case .property:     return "Property"
        case .otherAsset:   return "Other Asset"
        case .creditCard:   return "Credit Card"
        case .studentLoan:  return "Student Loan"
        case .mortgage:     return "Mortgage"
        case .autoLoan:     return "Auto Loan"
        case .personalLoan: return "Personal Loan"
        case .medicalDebt:  return "Medical"
        case .otherDebt:    return "Other Debt"
        }
    }

    var iconName: String {
        switch self {
        case .debit:        return "banknote.fill"
        case .savings:      return "dollarsign.bank.building.fill"
        case .investment:   return "chart.line.uptrend.xyaxis"
        case .property:     return "house.fill"
        case .otherAsset:   return "shippingbox.fill"
        case .creditCard:   return "creditcard.fill"
        case .studentLoan:  return "graduationcap.fill"
        case .mortgage:     return "house.lodge.fill"
        case .autoLoan:     return "car.fill"
        case .personalLoan: return "person.fill"
        case .medicalDebt:  return "cross.case.fill"
        case .otherDebt:    return "doc.text.fill"
        }
    }

    /// Accent color used in an account's detail header. Neutral sage for
    /// assets, muted terracotta for liabilities. Never used for row tint
    /// or decorative purposes elsewhere.
    var accentColor: Color {
        isAsset ? Theme.sage : Theme.terracotta
    }

    // MARK: - Convenience

    /// Every specific category under a given top-level kind.
    static func categories(for kind: Kind) -> [AccountCategory] {
        allCases.filter { $0.kind == kind }
    }
}
