//
//  BudgetEngine+SetupSignal.swift
//  Plenty
//
//  Target path: Plenty/Engine/BudgetEngine+SetupSignal.swift
//
//  Phase 1.1 (post-launch v1): centralized "does this user have any
//  setup data yet?" signal. Drives the empty-state branch on
//  Overview, and is intended for reuse by the iPhone widget and the
//  Watch home view so all three surfaces agree on the threshold.
//
//  Returns true the moment the user adds an account, transaction,
//  income source, or savings goal. Returns false only on the truly
//  empty first-launch state — and after a Start Fresh from demo
//  mode, since DemoModeService.clearAll() removes every record in
//  every model.
//
//  Subscriptions are intentionally excluded from the signal:
//  "suggested" subscriptions are inferred from existing transactions,
//  so by the time any exist this signal is already true via the
//  transactions check.
//

import Foundation

extension BudgetEngine {

    /// Whether the user has entered enough to compute a meaningful
    /// hero number. Used by Overview to decide between rendering
    /// `HeroNumberView` (with `monthlyBudgetRemaining`) and the
    /// `OverviewEmptyHero` first-run state.
    ///
    /// Default-empty arguments allow callers that don't track a model
    /// (e.g. widget snapshots that don't load IncomeSources) to omit
    /// it without misreporting.
    static func hasAnySetupData(
        accounts: [Account],
        transactions: [Transaction],
        incomeSources: [IncomeSource] = [],
        savingsGoals: [SavingsGoal] = []
    ) -> Bool {
        !accounts.isEmpty
            || !transactions.isEmpty
            || !incomeSources.isEmpty
            || !savingsGoals.isEmpty
    }
}
