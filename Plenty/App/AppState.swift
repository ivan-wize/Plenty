//
//  AppState.swift
//  Plenty
//
//  Target path: Plenty/App/AppState.swift
//
//  Phase 0 (v2): clean four-tab enum, no legacy cases.
//
//  v1 was never released, so this rewrites the Tab enum directly to the
//  final four-tab shape: overview / income / expenses / plan. Settings
//  is no longer a tab — it opens as a sheet from OverviewTopBar (P3).
//
//  Tab icons follow PDS §3:
//    • Overview → "circle.grid.2x2"      (proposed; final call open)
//    • Income   → "arrow.down.circle"
//    • Expenses → "arrow.up.circle"
//    • Plan     → "chart.line.uptrend.xyaxis"
//
//  PendingAddSheet is unchanged — every case is still reachable from
//  the FAB menu (Overview), per-tab toolbars, or App Intents.
//

import Foundation
import Observation

@Observable
@MainActor
final class AppState {

    // MARK: - Tab

    enum Tab: String, CaseIterable, Identifiable, Sendable {
        case overview, income, expenses, plan

        var id: String { rawValue }

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
            case .overview: return "circle.grid.2x2"
            case .income:   return "arrow.down.circle"
            case .expenses: return "arrow.up.circle"
            case .plan:     return "chart.line.uptrend.xyaxis"
            }
        }
    }

    var selectedTab: Tab = .overview

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

    // MARK: - Last Error

    /// The most recent app-level error worth surfacing to the user.
    /// Set by services (CloudKitSyncMonitor, save handlers, etc.) when
    /// something went wrong that needs user awareness. Cleared by
    /// ErrorBanner when the user dismisses it, or automatically by
    /// services when the underlying issue resolves.
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

    // MARK: - Settings Sheet (P3 hookup)

    /// Whether the Settings sheet is currently presented. Set true by
    /// OverviewTopBar's gear button (P3); presented by RootView.
    var showingSettingsSheet: Bool = false
}
