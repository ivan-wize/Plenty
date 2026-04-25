//
//  AppState.swift
//  Plenty
//
//  Target path: Plenty/App/AppState.swift
//
//  Phase 1 baseline: selectedTab, install date.
//  Phase 5 update: pendingAddSheet for cross-screen Add coordination.
//
//  Pattern: any view (HomeTab setup checklist, AccountsTab account row,
//  glance section, etc.) sets `appState.pendingAddSheet = .income` to
//  request a sheet. RootView observes and presents the corresponding
//  view. The sheet dismisses by clearing the binding back to nil.
//
//  This avoids the alternative of passing sheet bindings down through
//  every parent → child relationship that needs to trigger an Add.
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

    /// First-launch date, persisted to UserDefaults. Used by RatingManager,
    /// onboarding state checks, and "first N days" features.
    var installDate: Date {
        if let stored = UserDefaults.standard.object(forKey: Self.installDateKey) as? Date {
            return stored
        }
        let now = Date.now
        UserDefaults.standard.set(now, forKey: Self.installDateKey)
        return now
    }

    // MARK: - Pending Add Sheet (Phase 5)

    /// What sheet, if any, RootView should present. Setting this from
    /// any view triggers presentation. Cleared on dismiss. Identifiable
    /// so it works as a `.sheet(item:)` binding.
    var pendingAddSheet: PendingAddSheet?

    enum PendingAddSheet: Identifiable, Equatable, Sendable {

        /// Quick-add expense.
        case expense

        /// Manual income. `preferRecurring` controls whether the
        /// "make recurring" toggle is on by default. Setup checklist
        /// passes true; ad-hoc Add button passes false.
        case income(preferRecurring: Bool)

        /// New bill or edit existing.
        case bill(existing: Transaction? = nil)

        /// New account or edit existing.
        case account(existing: Account? = nil)

        /// Quick balance update for the given account.
        case updateBalance(Account)

        /// Confirm an expected-income entry that's arrived.
        case confirmIncome(Transaction)

        /// Add a subscription manually.
        case subscription

        var id: String {
            switch self {
            case .expense:                          return "expense"
            case .income(let recurring):            return "income.\(recurring)"
            case .bill(let existing):               return "bill.\(existing?.id.uuidString ?? "new")"
            case .account(let existing):            return "account.\(existing?.id.uuidString ?? "new")"
            case .updateBalance(let account):       return "balance.\(account.id.uuidString)"
            case .confirmIncome(let transaction):   return "confirm.\(transaction.id.uuidString)"
            case .subscription:                     return "subscription"
            }
        }
    }
}
