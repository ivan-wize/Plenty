//
//  AppState.swift
//  Plenty
//
//  Target path: Plenty/App/AppState.swift
//
//  Phase 5 (v2): added two scan-driven add-sheet cases:
//
//    .expenseFromScan(ReceiptDraft, Data?)
//      → Open AddExpenseSheet pre-filled with a ReceiptDraft and the
//        captured image. Used after the document scanner classifies a
//        document as a receipt.
//
//    .billFromScan(BillDraft, Data?)
//      → Open BillEditorSheet pre-filled with a BillDraft and the
//        captured image. Used after the document scanner classifies a
//        document as a bill.
//
//  Both cases use Equatable comparison by content; since drafts are
//  pure value types, this is safe and stable across re-fetches.
//

import Foundation
import SwiftUI

@Observable
final class AppState {

    // MARK: - Tabs

    enum Tab: Hashable {
        case overview
        case income
        case expenses
        case plan

        var title: String {
            switch self {
            case .overview: return "Overview"
            case .income:   return "Income"
            case .expenses: return "Expenses"
            case .plan:     return "Plan"
            }
        }

        var systemImage: String {
            switch self {
            case .overview: return "house"
            case .income:   return "arrow.down.circle"
            case .expenses: return "creditcard"
            case .plan:     return "chart.line.uptrend.xyaxis"
            }
        }
    }

    var selectedTab: Tab = .overview

    // MARK: - Settings sheet

    var showingSettingsSheet = false

    // MARK: - Pro

    /// Whether Plenty Pro is unlocked. Owned by StoreKitManager —
    /// refreshed at launch via `refreshEntitlements()` and updated by the
    /// transaction listener on purchase, restore, or revocation.
    var isProUnlocked: Bool = false

    // MARK: - Errors

    var lastError: PlentyError?

    // MARK: - Pending Add Sheet

    var pendingAddSheet: PendingAddSheet?

    enum PendingAddSheet: Identifiable, Equatable {
        case expense
        case expenseFromScan(ReceiptDraft, Data?)
        case income(preferRecurring: Bool)
        case bill(existing: Transaction? = nil)
        case billFromScan(BillDraft, Data?)
        case account(existing: Account? = nil)
        case updateBalance(Account)
        case confirmIncome(Transaction)
        case subscription
        case savingsGoal(existing: SavingsGoal? = nil)
        case logContribution(SavingsGoal)

        var id: String {
            switch self {
            case .expense:                          return "expense"
            case .expenseFromScan:                  return "expense.scan"
            case .income(let recurring):            return "income.\(recurring)"
            case .bill(let existing):               return "bill.\(existing?.id.uuidString ?? "new")"
            case .billFromScan:                     return "bill.scan"
            case .account(let existing):            return "account.\(existing?.id.uuidString ?? "new")"
            case .updateBalance(let account):       return "balance.\(account.id.uuidString)"
            case .confirmIncome(let transaction):   return "confirm.\(transaction.id.uuidString)"
            case .subscription:                     return "subscription"
            case .savingsGoal(let existing):        return "savingsGoal.\(existing?.id.uuidString ?? "new")"
            case .logContribution(let goal):        return "contribution.\(goal.id.uuidString)"
            }
        }

        // Manual Equatable: compare by id where possible (so two
        // fetches of the same record compare equal), and by content
        // for the value-type-only cases.
        static func == (lhs: PendingAddSheet, rhs: PendingAddSheet) -> Bool {
            switch (lhs, rhs) {
            case (.expense, .expense):
                return true
            case (.expenseFromScan(let a, let aImg), .expenseFromScan(let b, let bImg)):
                return a == b && aImg == bImg
            case (.income(let a), .income(let b)):
                return a == b
            case (.bill(let a), .bill(let b)):
                return a?.id == b?.id
            case (.billFromScan(let a, let aImg), .billFromScan(let b, let bImg)):
                return a == b && aImg == bImg
            case (.account(let a), .account(let b)):
                return a?.id == b?.id
            case (.updateBalance(let a), .updateBalance(let b)):
                return a.id == b.id
            case (.confirmIncome(let a), .confirmIncome(let b)):
                return a.id == b.id
            case (.subscription, .subscription):
                return true
            case (.savingsGoal(let a), .savingsGoal(let b)):
                return a?.id == b?.id
            case (.logContribution(let a), .logContribution(let b)):
                return a.id == b.id
            default:
                return false
            }
        }
    }
}
