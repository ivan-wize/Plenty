//
//  SubscriptionSuggestionsView.swift
//  Plenty
//
//  Target path: Plenty/Features/Accounts/SubscriptionSuggestionsView.swift
//
//  Focused review screen for subscriptions the detector found but the
//  user hasn't acted on. Reachable from SubscriptionsListView via a
//  banner ("Plenty found N possible subscriptions — review →") and
//  also from a notification deep link.
//
//  Differs from the suggestions section inline in SubscriptionsListView
//  by:
//    • Showing detection rationale per row (cadence, last seen,
//      typical amount range)
//    • Confirming and dismissing in batch via swipe + actions
//    • Empty-state messaging when the queue is clear
//
//  PRD §9.5: subscription detection runs against transaction history.
//  This view surfaces the output for user review and is the only place
//  where the rationale ("we saw 3 charges of about $9.99 every 30
//  days") is exposed.
//

import SwiftUI
import SwiftData

struct SubscriptionSuggestionsView: View {

    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<Subscription> { $0.stateRaw == "suggested" },
        sort: \Subscription.merchantName
    )
    private var suggestions: [Subscription]

    var body: some View {
        Group {
            if suggestions.isEmpty {
                emptyState
            } else {
                List {
                    Section {
                        ForEach(suggestions) { sub in
                            suggestionRow(sub)
                                .swipeActions(edge: .trailing) {
                                    Button("Dismiss", role: .destructive) {
                                        dismissSuggestion(sub)
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    Button("Confirm") {
                                        confirmSuggestion(sub)
                                    }
                                    .tint(Theme.sage)
                                }
                        }
                    } header: {
                        Text("\(suggestions.count) found")
                    } footer: {
                        Text("Confirm to track a subscription. Dismiss to tell Plenty it isn't recurring — we won't suggest it again.")
                            .font(Typography.Support.caption)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Suggestions")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Row

    private func suggestionRow(_ sub: Subscription) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.body)
                .foregroundStyle(Theme.amber)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Theme.amber.opacity(Theme.Opacity.soft)))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(sub.merchantName)
                        .font(Typography.Body.emphasis)
                    Spacer()
                    Text(sub.typicalAmount.asPlainCurrency())
                        .font(Typography.Currency.row.monospacedDigit())
                        .foregroundStyle(.primary)
                }

                Text(rationale(for: sub))
                    .font(Typography.Support.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    Button {
                        confirmSuggestion(sub)
                    } label: {
                        Text("Confirm")
                            .font(Typography.Support.footnote.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Theme.sage))
                    }
                    .buttonStyle(.plain)

                    Button {
                        dismissSuggestion(sub)
                    } label: {
                        Text("Not a sub")
                            .font(Typography.Support.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Rationale

    private func rationale(for sub: Subscription) -> String {
        var parts: [String] = []
        parts.append("\(sub.cadence.displayName.lowercased()) charge")

        if let last = sub.lastChargeDate {
            let formatted = last.formatted(.dateTime.month(.abbreviated).day())
            parts.append("last seen \(formatted)")
        }

        let monthly = sub.monthlyCost.asPlainCurrency()
        parts.append("about \(monthly)/mo")

        return parts.joined(separator: " · ").capitalizedFirst
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Nothing to review", systemImage: "checkmark.circle")
        } description: {
            Text("Plenty hasn't found any new subscriptions in your transaction history. The detector runs after each import and after manual transactions are added.")
        }
    }

    // MARK: - Actions

    private func confirmSuggestion(_ sub: Subscription) {
        sub.confirm()
        try? modelContext.save()
    }

    private func dismissSuggestion(_ sub: Subscription) {
        sub.dismiss()
        try? modelContext.save()
    }
}

// MARK: - Local helpers

private extension Decimal {
    func asPlainCurrency() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        let asDouble = NSDecimalNumber(decimal: self).doubleValue
        if asDouble == asDouble.rounded() {
            formatter.maximumFractionDigits = 0
            formatter.minimumFractionDigits = 0
        } else {
            formatter.maximumFractionDigits = 2
            formatter.minimumFractionDigits = 2
        }
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "$\(self)"
    }
}

private extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
