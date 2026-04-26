//
//  TransactionRow.swift
//  Plenty
//
//  Target path: Plenty/Features/Accounts/TransactionRow.swift
//
//  Single row for a Transaction. Used in TransactionsListView, the
//  glance section, and AccountDetailView's transactions section.
//
//  Sign convention by kind:
//    .expense, .bill, .transfer (out of account)  → leading minus
//    .income                                       → leading plus
//

import SwiftUI

struct TransactionRow: View {

    let transaction: Transaction

    var body: some View {
        HStack(spacing: 14) {
            iconCircle

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.name)
                    .font(Typography.Body.regular)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(secondaryText)
                    .font(Typography.Support.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(formattedAmount)
                .font(Typography.Body.emphasis.monospacedDigit())
                .foregroundStyle(amountColor)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Subviews

    private var iconCircle: some View {
        Image(systemName: iconName)
            .font(.body.weight(.medium))
            .foregroundStyle(Theme.sage)
            .symbolRenderingMode(.hierarchical)
            .frame(width: 36, height: 36)
            .background(
                Circle().fill(Theme.sage.opacity(Theme.Opacity.soft))
            )
    }

    // MARK: - Computed

    private var iconName: String {
        transaction.category?.iconName ?? transaction.kind.symbolName
    }

    private var secondaryText: String {
        let dateLabel = TransactionRow.dateFormatter.string(from: transaction.date)
        if let category = transaction.category {
            return "\(category.displayName) · \(dateLabel)"
        }
        return dateLabel
    }

    private var formattedAmount: String {
        let amount = transaction.amount.asPlainCurrency()
        switch transaction.kind {
        case .income:
            return "+\(amount)"
        case .expense, .bill, .transfer:
            return "−\(amount)"
        }
    }

    private var amountColor: Color {
        switch transaction.kind {
        case .income:                       return Theme.sage
        case .expense, .bill, .transfer:    return .primary
        }
    }

    private var accessibilityLabel: String {
        let dateLabel = TransactionRow.dateFormatter.string(from: transaction.date)
        let amount = transaction.amount.asPlainCurrency()
        let direction = transaction.kind == .income ? "credit" : "debit"
        return "\(transaction.name), \(direction) \(amount), \(dateLabel)"
    }

    // MARK: - Formatter

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()
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
