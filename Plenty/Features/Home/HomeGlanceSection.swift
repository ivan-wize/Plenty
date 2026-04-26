//
//  HomeGlanceSection.swift
//  Plenty
//
//  Target path: Plenty/Features/Home/HomeGlanceSection.swift
//
//  The "Coming up" section beneath the hero. Up to five items:
//  unpaid bills due this month and expected income arriving this
//  month, sorted by date. Empty state hidden — when nothing is
//  pending, this section renders nothing.
//
//  Phase 4: row taps are no-ops. Phase 5 wires:
//    • Bill row → BillEditorSheet (mark paid / edit)
//    • Income row → ConfirmIncomeSheet
//

import SwiftUI

struct HomeGlanceSection: View {

    let bills: [Transaction]      // unpaid bills this month, by dueDay
    let income: [Transaction]     // expected income this month, by date

    var onTapBill: (Transaction) -> Void = { _ in }
    var onTapIncome: (Transaction) -> Void = { _ in }

    // MARK: - Body

    var body: some View {
        if combined.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                header

                VStack(spacing: 0) {
                    ForEach(Array(combined.prefix(5).enumerated()), id: \.element.id) { index, item in
                        row(for: item)
                        if index < min(4, combined.count - 1) {
                            divider
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .fill(Theme.cardSurface)
                )
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Coming up")
                .font(Typography.Support.label)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.6)

            Spacer()
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Row

    @ViewBuilder
    private func row(for item: GlanceItem) -> some View {
        Button {
            switch item.kind {
            case .bill:   onTapBill(item.transaction)
            case .income: onTapIncome(item.transaction)
            }
        } label: {
            HStack(spacing: 14) {
                icon(for: item)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.transaction.name)
                        .font(Typography.Body.regular)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(dateLine(for: item))
                        .font(Typography.Support.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(amountLine(for: item))
                    .font(Typography.Body.emphasis.monospacedDigit())
                    .foregroundStyle(amountColor(for: item))
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: item))
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.secondary.opacity(Theme.Opacity.hairline))
            .frame(height: 0.5)
            .padding(.leading, 50)
    }

    // MARK: - Per-Row Helpers

    private func icon(for item: GlanceItem) -> some View {
        let symbolName: String
        let tint: Color
        switch item.kind {
        case .bill:
            symbolName = "doc.text"
            tint = Theme.sage
        case .income:
            symbolName = "arrow.down.circle"
            tint = Theme.sage
        }

        return Image(systemName: symbolName)
            .font(.body.weight(.medium))
            .foregroundStyle(tint)
            .symbolRenderingMode(.hierarchical)
            .frame(width: 32, height: 32)
            .background(
                Circle().fill(tint.opacity(Theme.Opacity.soft))
            )
    }

    private func dateLine(for item: GlanceItem) -> String {
        let date = item.sortDate
        let cal = Calendar.current
        let now = Date.now

        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }

        let days = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: date)).day ?? 0

        if days < 0 {
            return "Overdue"
        } else if days <= 7 {
            return Self.weekdayFormatter.string(from: date)
        } else {
            return Self.shortDateFormatter.string(from: date)
        }
    }

    private func amountLine(for item: GlanceItem) -> String {
        let value: Decimal
        switch item.kind {
        case .bill:
            value = item.transaction.amount
        case .income:
            value = item.transaction.expectedAmount
        }
        return value.asPlainCurrency()
    }

    private func amountColor(for item: GlanceItem) -> Color {
        switch item.kind {
        case .bill:
            // Overdue gets terracotta; otherwise neutral primary.
            let cal = Calendar.current
            let isOverdue = item.sortDate < cal.startOfDay(for: .now)
            return isOverdue ? Theme.terracotta : .primary
        case .income:
            return .primary
        }
    }

    private func accessibilityLabel(for item: GlanceItem) -> String {
        let kindWord = item.kind == .bill ? "Bill" : "Expected income"
        let amount = amountLine(for: item)
        let when = dateLine(for: item)
        return "\(kindWord), \(item.transaction.name), \(amount), \(when)"
    }

    // MARK: - Combined Items

    private var combined: [GlanceItem] {
        let billItems = bills.map { GlanceItem(transaction: $0, kind: .bill) }
        let incomeItems = income.map { GlanceItem(transaction: $0, kind: .income) }
        return (billItems + incomeItems).sorted { $0.sortDate < $1.sortDate }
    }

    // MARK: - Item

    private struct GlanceItem: Identifiable {
        let transaction: Transaction
        let kind: Kind

        var id: UUID { transaction.id }

        enum Kind { case bill, income }

        /// The date used for ordering and display. Bills sort by their
        /// computed due date; income sorts by its scheduled date.
        var sortDate: Date {
            switch kind {
            case .bill:
                let cal = Calendar.current
                var comps = DateComponents()
                comps.year = transaction.year
                comps.month = transaction.month
                comps.day = transaction.dueDay
                return cal.date(from: comps) ?? transaction.date
            case .income:
                return transaction.date
            }
        }
    }

    // MARK: - Formatters

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f
    }()

    private static let shortDateFormatter: DateFormatter = {
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
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "$\(self)"
    }
}
