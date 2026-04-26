//
//  BillRow.swift
//  Plenty
//
//  Target path: Plenty/Features/Accounts/BillRow.swift
//
//  Single row for a Bill (Transaction with kind == .bill). Leading
//  tappable circle marks paid/unpaid. Name, due day, amount.
//
//  Used in BillsListView and (via wrapping) in HomeGlanceSection.
//

import SwiftUI
import SwiftData

struct BillRow: View {

    let bill: Transaction
    let onTogglePaid: () -> Void
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            paidToggle

            Button(action: onTap) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(bill.name)
                            .font(Typography.Body.regular)
                            .foregroundStyle(bill.isPaid ? .secondary : .primary)
                            .strikethrough(bill.isPaid, color: .secondary)
                            .lineLimit(1)

                        Text(secondaryText)
                            .font(Typography.Support.footnote)
                            .foregroundStyle(secondaryColor)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(bill.amount.asPlainCurrency())
                        .font(Typography.Body.emphasis.monospacedDigit())
                        .foregroundStyle(bill.isPaid ? .secondary : .primary)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Paid Toggle

    private var paidToggle: some View {
        Button {
            onTogglePaid()
        } label: {
            Image(systemName: bill.isPaid ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(bill.isPaid ? Theme.sage : .tertiary)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 28, height: 28)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: bill.isPaid)
        .accessibilityLabel(bill.isPaid ? "Paid" : "Mark paid")
    }

    // MARK: - Secondary Line

    private var secondaryText: String {
        let cal = Calendar.current
        var comps = DateComponents()
        comps.year = bill.year
        comps.month = bill.month
        comps.day = bill.dueDay
        let dueDate = cal.date(from: comps) ?? bill.date

        if bill.isPaid {
            if let paidAt = bill.paidAt {
                return "Paid \(BillRow.dateFormatter.string(from: paidAt))"
            }
            return "Paid"
        }

        let now = Date.now
        let daysUntil = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: dueDate)).day ?? 0

        if daysUntil < 0 {
            return "Overdue"
        }
        if daysUntil == 0 {
            return "Due today"
        }
        if daysUntil == 1 {
            return "Due tomorrow"
        }
        if daysUntil <= 7 {
            return "Due \(BillRow.weekdayFormatter.string(from: dueDate))"
        }
        return "Due \(bill.dueDay.ordinal)"
    }

    private var secondaryColor: Color {
        if bill.isPaid { return .secondary }

        let cal = Calendar.current
        var comps = DateComponents()
        comps.year = bill.year
        comps.month = bill.month
        comps.day = bill.dueDay
        let dueDate = cal.date(from: comps) ?? bill.date
        let isOverdue = dueDate < cal.startOfDay(for: .now)

        return isOverdue ? Theme.terracotta : .secondary
    }

    private var accessibilityLabel: String {
        let amount = bill.amount.asPlainCurrency()
        let status = bill.isPaid ? "paid" : "unpaid"
        return "\(bill.name), \(amount), \(status), \(secondaryText)"
    }

    // MARK: - Formatters

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f
    }()
}

// MARK: - Decimal Helper

private extension Decimal {
    func asPlainCurrency() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "$\(self)"
    }
}
