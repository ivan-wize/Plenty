//
//  SubscriptionRow.swift
//  Plenty
//
//  Target path: Plenty/Features/Accounts/SubscriptionRow.swift
//
//  Single row for a Subscription. Shows merchant, monthly cost, next
//  charge date, and a "to cancel" indicator if isMarkedToCancel is on.
//
//  Phase 5 interactions:
//    • Tap row → toggle isMarkedToCancel
//    • Swipe → delete (handled by parent List)
//
//  Phase 7 will add the EventKit reminder when isMarkedToCancel flips on.
//

import SwiftUI

struct SubscriptionRow: View {

    let subscription: Subscription
    let onToggleCancel: () -> Void

    var body: some View {
        Button(action: onToggleCancel) {
            HStack(spacing: 14) {
                iconCircle

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(subscription.merchantName)
                            .font(Typography.Body.regular)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if subscription.isMarkedToCancel {
                            cancelBadge
                        }

                        if subscription.state == .suggested {
                            suggestedBadge
                        }
                    }

                    Text(secondaryText)
                        .font(Typography.Support.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(subscription.monthlyCost.asPlainCurrency())
                        .font(Typography.Body.emphasis.monospacedDigit())
                        .foregroundStyle(.primary)

                    Text("/ mo")
                        .font(Typography.Support.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Icon

    private var iconCircle: some View {
        Image(systemName: "arrow.triangle.2.circlepath")
            .font(.body.weight(.medium))
            .foregroundStyle(Theme.sage)
            .symbolRenderingMode(.hierarchical)
            .frame(width: 36, height: 36)
            .background(
                Circle().fill(Theme.sage.opacity(Theme.Opacity.soft))
            )
    }

    // MARK: - Badges

    private var cancelBadge: some View {
        Text("To cancel")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Theme.terracotta)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(Theme.terracotta.opacity(Theme.Opacity.soft))
            )
    }

    private var suggestedBadge: some View {
        Text("Suggested")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Theme.amber)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(Theme.amber.opacity(Theme.Opacity.soft))
            )
    }

    // MARK: - Computed

    private var secondaryText: String {
        let cadence = subscription.cadence.displayName.lowercased()

        if let next = subscription.nextChargeDate {
            let cal = Calendar.current
            let days = cal.dateComponents([.day], from: cal.startOfDay(for: .now), to: cal.startOfDay(for: next)).day ?? 0
            if days < 0 {
                return "\(cadence) · charge expected"
            }
            if days == 0 {
                return "\(cadence) · charges today"
            }
            if days == 1 {
                return "\(cadence) · charges tomorrow"
            }
            if days <= 30 {
                return "\(cadence) · in \(days) days"
            }
        }
        return cadence
    }

    private var accessibilityLabel: String {
        let amount = subscription.monthlyCost.asPlainCurrency()
        var label = "\(subscription.merchantName), \(amount) per month, \(subscription.cadence.displayName)"
        if subscription.isMarkedToCancel {
            label += ", marked to cancel"
        }
        return label
    }
}

// MARK: - Decimal Helper

private extension Decimal {
    func asPlainCurrency() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "$\(self)"
    }
}
