//
//  AppState.swift
//  Plenty
//
//  Target path: Plenty/App/AppState.swift
//
//  Phase 1: selectedTab, install date.
//  Phase 5: pendingAddSheet enum.
//  Phase 6: isProUnlocked.
//  Phase 10: + lastError for app-level error banner.
//
//  IMPORTANT: PendingAddSheet is NOT Sendable. Several cases hold
//  references to SwiftData @Model classes (Transaction, Account,
//  SavingsGoal), which are MainActor-isolated and not Sendable. The
//  whole AppState is @MainActor so this is safe — the enum never
//  crosses isolation domains in practice.
//
//  Equatable is implemented manually because synthesized Equatable on
//  enum cases that hold SwiftData model references can match by
//  reference identity in surprising ways. We compare by `id` so two
//  fetches of the same record compare equal.
//

import Foundation
import Observation

@Observable
@MainActor
final class AppState {

    // MARK: - Tab

    enum Tab: String, CaseIterable, Identifiable, Sendable {
        case home, accounts, plan, settings

        var id: String { rawValue }

        var title: String {
            switch self {
            case .home:     return "Home"
            case .accounts: return "Accounts"
            case .plan:     return "Plan"
            case .settings: return "Settings"
            }
        }

        var systemImage: String {
            switch self {
            case .home:     return "house"
            case .accounts: return "creditcard.and.123"
            case .plan:     return "chart.line.uptrend.xyaxis"
            case .settings: return "gearshape"
            }
        }
    }

    var selectedTab: Tab = .home

    // MARK: - Install Date

    private static let installDateKey = "plenty.installDate"

    var installDate: Date {
        if let stored = UserDefaults.standard.object(forKey: Self.installDateKey) as? Date {
            return stored
        }
        let now = Date.now
        UserDefaults.standard.set(now, forKey: Self.installDateKey)
        return now
    }

    // MARK: - Pro Access

    var isProUnlocked: Bool = false

    // MARK: - Last Error (Phase 10)

    /// The most recent app-level error worth surfacing to the user.
    /// Set by services (CloudKitSyncMonitor, save handlers, etc.)
    /// when something went wrong that needs user awareness. Cleared
    /// by ErrorBanner when the user dismisses it, or automatically
    /// by services when the underlying issue resolves.
    var lastError: PlentyError?

    // MARK: - Pending Add Sheet

    var pendingAddSheet: PendingAddSheet?

    enum PendingAddSheet: Identifiable, Equatable {
        case expense
        case income(preferRecurring: Bool)
        case bill(existing: Transaction? = nil)
        case account(existing: Account? = nil)
        case updateBalance(Account)
        case confirmIncome(Transaction)
        case subscription
        case savingsGoal(existing: SavingsGoal? = nil)
        case logContribution(SavingsGoal)

        var id: String {
            switch self {
            case .expense:                          return "expense"
            case .income(let recurring):            return "income.\(recurring)"
            case .bill(let existing):               return "bill.\(existing?.id.uuidString ?? "new")"
            case .account(let existing):            return "account.\(existing?.id.uuidString ?? "new")"
            case .updateBalance(let account):       return "balance.\(account.id.uuidString)"
            case .confirmIncome(let transaction):   return "confirm.\(transaction.id.uuidString)"
            case .subscription:                     return "subscription"
            case .savingsGoal(let existing):        return "savingsGoal.\(existing?.id.uuidString ?? "new")"
            case .logContribution(let goal):        return "contribution.\(goal.id.uuidString)"
            }
        }

        // Manual Equatable: compare by id so two fetches of the same
        // record compare equal. Synthesized Equatable on @Model classes
        // can be reference-based in subtle ways.
        static func == (lhs: PendingAddSheet, rhs: PendingAddSheet) -> Bool {
            switch (lhs, rhs) {
            case (.expense, .expense):
                return true
            case (.income(let a), .income(let b)):
                return a == b
            case (.bill(let a), .bill(let b)):
                return a?.id == b?.id
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
