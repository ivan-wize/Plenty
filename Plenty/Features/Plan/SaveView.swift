//
//  SaveView.swift
//  Plenty
//
//  Target path: Plenty/Features/Plan/SaveView.swift
//
//  The Save mode of the Plan tab. Two main sections:
//
//    1. Savings Goals — list of goals with progress bars. Tap to log a
//       contribution; menu to edit or delete.
//    2. Debt Payoff — the avalanche vs snowball comparison card.
//

import SwiftUI
import SwiftData

struct SaveView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @Query private var allGoals: [SavingsGoal]

    @Query(sort: \Account.sortOrder)
    private var allAccounts: [Account]

    private var debtAccounts: [Account] {
        allAccounts.filter { !$0.isAsset && $0.balance > 0 }
    }

    private var hasContent: Bool {
        !allGoals.isEmpty || !debtAccounts.isEmpty
    }

    // MARK: - Body

    var body: some View {
        if !hasContent {
            emptyState
        } else {
            ScrollView {
                VStack(spacing: 20) {
                    if !allGoals.isEmpty {
                        goalsSection
                    } else {
                        addGoalPrompt
                    }

                    if !debtAccounts.isEmpty {
                        DebtPayoffPlanCard(
                            debts: debtAccounts,
                            monthlyExtraPayment: 0
                        )
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 16)
            }
        }
    }

    // MARK: - Goals Section

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Savings Goals")
                    .font(Typography.Title.small)
                Spacer()
                Button {
                    appState.pendingAddSheet = .savingsGoal()
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.title3)
                        .foregroundStyle(Theme.sage)
                }
            }

            VStack(spacing: 12) {
                ForEach(allGoals) { goal in
                    GoalRow(
                        goal: goal,
                        onTap: {
                            appState.pendingAddSheet = .logContribution(goal)
                        },
                        onEdit: {
                            appState.pendingAddSheet = .savingsGoal(existing: goal)
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private var addGoalPrompt: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Savings Goals")
                .font(Typography.Title.small)

            Button {
                appState.pendingAddSheet = .savingsGoal()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "leaf")
                        .font(.title3)
                        .foregroundStyle(Theme.sage)
                        .frame(width: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Add a savings goal")
                            .font(Typography.Body.regular)
                            .foregroundStyle(.primary)
                        Text("A trip, a fund, anything you're working toward.")
                            .font(Typography.Support.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .fill(Theme.cardSurface)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Plan a save", systemImage: "leaf")
        } description: {
            Text("Set a savings goal or add a debt account to see your payoff path.")
        } actions: {
            Button {
                appState.pendingAddSheet = .savingsGoal()
            } label: {
                Text("Add a goal").fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.sage)
        }
    }
}

// MARK: - Goal Row

private struct GoalRow: View {
    let goal: SavingsGoal
    let onTap: () -> Void
    let onEdit: () -> Void

    private var progress: Double {
        guard goal.targetAmount > 0 else { return 0 }
        return min(1, max(0, (goal.contributedAmount / goal.targetAmount as NSDecimalNumber).doubleValue))
    }

    private var progressColor: Color {
        if progress >= 1 { return Theme.sage }
        if progress >= 0.66 { return Theme.sage }
        if progress >= 0.33 { return Theme.amber }
        return .secondary.opacity(0.6)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(goal.name)
                                .font(Typography.Body.emphasis)
                                .foregroundStyle(.primary)

                            if progress >= 1 {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Theme.sage)
                                    .font(.subheadline)
                            }
                        }

                        if let deadline = goal.deadline {
                            Text("By \(deadline.formatted(date: .abbreviated, time: .omitted))")
                                .font(Typography.Support.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(goal.goalType.displayName)
                                .font(Typography.Support.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Menu {
                        Button {
                            onTap()
                        } label: {
                            Label("Log Contribution", systemImage: "plus.circle")
                        }
                        Button {
                            onEdit()
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                }

                ProgressView(value: progress)
                    .tint(progressColor)

                HStack {
                    Text("\(goal.contributedAmount.asPlainCurrency()) of \(goal.targetAmount.asPlainCurrency())")
                        .font(Typography.Support.footnote)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Spacer()
                    Text("\(Int((progress * 100).rounded()))%")
                        .font(Typography.Support.footnote.weight(.semibold))
                        .foregroundStyle(progressColor)
                        .monospacedDigit()
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.cardSurface)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private extension Decimal {
    func asPlainCurrency() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "$\(self)"
    }
}
