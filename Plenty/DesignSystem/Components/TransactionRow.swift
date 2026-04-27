//
//  TransactionRow.swift
//  Plenty
//
//  Target path: Plenty/Features/Accounts/TransactionRow.swift
//
//  A row in any transaction list. Used by AccountDetailView (recent
//  transactions section), TransactionsListView (full history), and
//  AccountTransactionsView (per-account history).
//
//  Layout:
//    [icon]  Name                                        ±$amount
//            Category · Account                          relative date
//
//  Sign and color of amount derive from kind:
//    • expense, bill   → terracotta, prefix "−"
//    • income          → sage, prefix "+"
//    • transfer        → secondary, prefix "→"
//
//  Bills additionally show a paid-state indicator (sage check or
//  amber clock) before the name.
//

import SwiftUI

struct TransactionRow: View {

    let transaction: Transaction

    /// Whether to show the source/destination account in the secondary
    /// line. Defaults to true. Set to false in per-account views where
    /// every row is for the same account anyway.
    var showsAccount: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            iconBadge

            VStack(alignment: .leading, spacing: 2) {
                primaryLine
                secondaryLine
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 2) {
                amount
                date
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    // MARK: - Icon

    private var iconBadge: some View {
        Image(systemName: iconName)
            .font(.body)
            .foregroundStyle(iconTint)
            .symbolRenderingMode(.hierarchical)
            .frame(width: 32, height: 32)
            .background(Circle().fill(iconTint.opacity(Theme.Opacity.soft)))
    }

    private var iconName: String {
        if transaction.kind == .bill, transaction.isPaid {
            return "checkmark.circle.fill"
        }
        if transaction.kind == .bill, !transaction.isPaid {
            return "clock.fill"
        }
        return transaction.category?.iconName ?? defaultIcon
    }

    private var defaultIcon: String {
        switch transaction.kind {
        case .expense:  return "creditcard"
        case .bill:     return "doc.text"
        case .income:   return "arrow.down.circle"
        case .transfer: return "arrow.left.arrow.right"
        }
    }

    private var iconTint: Color {
        switch transaction.kind {
        case .bill where transaction.isPaid: return Theme.sage
        case .bill where !transaction.isPaid: return Theme.amber
        case .income:                         return Theme.sage
        case .expense, .transfer:             return Theme.sage
        case .bill:                           return Theme.sage  // exhaustiveness
        }
    }

    // MARK: - Lines

    private var primaryLine: some View {
        Text(transaction.name)
            .font(Typography.Body.regular)
            .foregroundStyle(.primary)
            .lineLimit(1)
    }

    @ViewBuilder
    private var secondaryLine: some View {
        let parts = secondaryParts
        if !parts.isEmpty {
            Text(parts.joined(separator: " · "))
                .font(Typography.Support.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var secondaryParts: [String] {
        var parts: [String] = []
        if let category = transaction.category {
            parts.append(category.displayName)
        }
        if showsAccount {
            if let source = transaction.sourceAccount {
                parts.append(source.name)
            } else if let destination = transaction.destinationAccount {
                parts.append(destination.name)
            }
        }
        return parts
    }

    // MARK: - Amount + Date

    private var amount: some View {
        Text(amountString)
            .font(Typography.Currency.row.monospacedDigit())
            .foregroundStyle(amountTint)
            .lineLimit(1)
    }

    private var amountString: String {
        let formatted = transaction.amount.asCleanCurrency()
        switch transaction.kind {
        case .expense, .bill: return "−\(formatted)"
        case .income:         return "+\(formatted)"
        case .transfer:       return formatted
        }
    }

    private var amountTint: Color {
        switch transaction.kind {
        case .expense, .bill: return Theme.terracotta
        case .income:         return Theme.sage
        case .transfer:       return .secondary
        }
    }

    private var date: some View {
        Text(transaction.date.formatted(.dateTime.month(.abbreviated).day()))
            .font(Typography.Support.caption)
            .foregroundStyle(.tertiary)
            .monospacedDigit()
    }
}

