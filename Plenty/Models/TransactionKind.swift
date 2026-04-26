//
//  TransactionKind.swift
//  Plenty
//
//  Target path: Plenty/Models/TransactionKind.swift
//
//  The four kinds of Transaction. Stored as a raw String on Transaction
//  for CloudKit compatibility.
//

import Foundation

enum TransactionKind: String, Codable, CaseIterable, Identifiable, Sendable {

    /// A one-time expense. Groceries, coffee, a vet visit.
    case expense

    /// A recurring obligation. Rent, subscriptions, insurance.
    case bill

    /// Money arriving. Paycheck, refund, gift.
    case income

    /// Money moving between accounts. Credit card payment, savings
    /// contribution, loan payment, investment contribution.
    case transfer

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .expense:  return "Expense"
        case .bill:     return "Bill"
        case .income:   return "Income"
        case .transfer: return "Transfer"
        }
    }

    /// SF Symbol that represents this kind in list rows.
    var symbolName: String {
        switch self {
        case .expense:  return "cart"
        case .bill:     return "doc.text"
        case .income:   return "arrow.down.circle"
        case .transfer: return "arrow.left.arrow.right"
        }
    }

    /// Whether a transaction of this kind reduces a cash balance.
    var reducesCash: Bool {
        switch self {
        case .expense, .bill: return true
        case .income:         return false
        case .transfer:       return true   // reduces source, increases destination
        }
    }
}
