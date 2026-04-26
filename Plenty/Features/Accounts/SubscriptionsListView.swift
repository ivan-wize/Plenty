//
//  SubscriptionsListView.swift
//  Plenty
//
//  Target path: Plenty/Features/Accounts/SubscriptionsListView.swift
//
//  Lists subscriptions grouped:
//    • Tracked (state == .confirmed)
//    • Suggested (state == .suggested) — populated by Phase 7 detection
//
//  Header shows the annualized cost across all tracked subscriptions.
//  Tap a row toggles its isMarkedToCancel flag. Swipe to delete.
//  Toolbar Add for manual entry.
//

import SwiftUI
import SwiftData

struct SubscriptionsListView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @Query(sort: \Subscription.merchantName) private var allSubscriptions: [Subscription]

    private var tracked: [Subscription] {
        allSubscriptions.filter { $0.state == .confirmed }
    }

    private var suggested: [Subscription] {
        allSubscriptions.filter { $0.state == .suggested }
    }

    private var totalAnnual: Decimal {
        tracked.reduce(Decimal.zero) { $0 + $1.annualCost }
    }

    private var totalMonthly: Decimal {
        tracked.reduce(Decimal.zero) { $0 + $1.monthlyCost }
    }

    // MARK: - Body

    var body: some View {
        Group {
            if allSubscriptions.isEmpty {
                ContentUnavailableView {
                    Label("No subscriptions yet", systemImage: "arrow.triangle.2.circlepath")
                } description: {
                    Text("Add a subscription to track it. Plenty will also detect new ones from your transaction history.")
                } actions: {
                    Button {
                        appState.pendingAddSheet = .subscription
                    } label: {
                        Text("Add subscription").fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.sage)
                }
            } else {
                List {
                    if !tracked.isEmpty {
                        Section {
                            ForEach(tracked) { sub in
                                SubscriptionRow(
                                    subscription: sub,
                                    onToggleCancel: { toggleCancel(sub) }
                                )
                            }
                            .onDelete { indexSet in delete(at: indexSet, in: tracked) }
                        } header: {
                            HStack {
                                Text("Tracked")
                                Spacer()
                                Text("\(totalMonthly.asPlainCurrency()) / mo")
                                    .monospacedDigit()
                            }
                        } footer: {
                            Text("Subscriptions cost you about \(totalAnnual.asPlainCurrency()) a year.")
                                .font(Typography.Support.caption)
                        }
                    }

                    if !suggested.isEmpty {
                        Section("Suggested") {
                            ForEach(suggested) { sub in
                                SubscriptionRow(
                                    subscription: sub,
                                    onToggleCancel: { confirm(sub) }
                                )
                                .swipeActions(edge: .trailing) {
                                    Button("Dismiss", role: .destructive) {
                                        sub.dismiss()
                                        try? modelContext.save()
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    Button("Confirm") {
                                        confirm(sub)
                                    }
                                    .tint(Theme.sage)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Subscriptions")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    appState.pendingAddSheet = .subscription
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    // MARK: - Actions

    private func toggleCancel(_ sub: Subscription) {
        if sub.isMarkedToCancel {
            sub.unmarkToCancel()
        } else {
            sub.markToCancel()
        }
        try? modelContext.save()
    }

    private func confirm(_ sub: Subscription) {
        sub.confirm()
        try? modelContext.save()
    }

    private func delete(at offsets: IndexSet, in subs: [Subscription]) {
        for index in offsets {
            modelContext.delete(subs[index])
        }
        try? modelContext.save()
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
