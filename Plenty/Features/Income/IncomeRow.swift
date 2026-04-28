//
//  IncomeRow.swift
//  Plenty
//
//  Target path: Plenty/Features/Income/IncomeRow.swift
//
//  Phase 4 (v2): single row used by IncomeListView for both Confirmed
//  and Expected income entries.
//
//  Layout mirrors BillRow's pattern for consistency:
//
//      [icon]  Paycheck                                  $2,400
//              Biweekly · Friday Apr 19         (or "Confirmed Apr 19")
//
//  Visual states:
//    • Expected   — clock icon, primary text, terracotta-tinted if past
//                   due (the date has passed but income hasn't confirmed)
//    • Confirmed  — sage check icon, secondary text (struck through? no
//                   — confirmed income shouldn't read as "done" in the
//                   pejorative sense; a calm check is enough)
//

import SwiftUI

struct IncomeRow: View {

    let transaction: Transaction
    var onTap: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            iconBadge

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.name)
                    .font(Typography.Body.regular)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(secondaryText)
                    .font(Typography.Support.footnote)
                    .foregroundStyle(secondaryColor)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Text(displayAmount.asPlainCurrency())
                .font(Typography.Body.emphasis.monospacedDigit())
                .foregroundStyle(transaction.incomeStatus == .confirmed ? Theme.sage : .primary)
                .lineLimit(1)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(onTap == nil ? [] : .isButton)
    }

    // MARK: - Icon

    private var iconBadge: some View {
        Image(systemName: iconName)
            .font(.body)
            .foregroundStyle(iconTint)
            .symbolRenderingMode(.hierarchical)
            .frame(width: 32, height: 32)
            .background(Circle().fill(iconTint.opacity(Theme.Opacity.soft)))
            .contentTransition(.symbolEffect(.replace))
    }

    private var iconName: String {
        transaction.incomeStatus == .confirmed
            ? "checkmark.circle.fill"
            : "clock.fill"
    }

    private var iconTint: Color {
        switch transaction.incomeStatus {
        case .confirmed:
            return Theme.sage
        case .expected:
            return isPastDue ? Theme.terracotta : .secondary
        case .skipped:
            return .secondary
        }
    }

    // MARK: - Secondary Line

    private var secondaryText: String {
        switch transaction.incomeStatus {
        case .confirmed:
            if let confirmedDate = confirmedDate {
                return "Confirmed \(IncomeRow.dayFormatter.string(from: confirmedDate))"
            }
            return "Confirmed"

        case .expected:
            return expectedSecondaryText

        case .skipped:
            return "Skipped this occurrence"
        }
    }

    private var expectedSecondaryText: String {
        let cal = Calendar.current
        let now = Date.now
        let daysOut = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: transaction.date)).day ?? 0

        if daysOut < 0 {
            // Past due — paycheck didn't arrive (or hasn't been confirmed)
            return "Was expected \(IncomeRow.dayFormatter.string(from: transaction.date))"
        }
        if daysOut == 0 {
            return "Expected today"
        }
        if daysOut == 1 {
            return "Expected tomorrow"
        }
        if daysOut <= 7 {
            return "Expected \(IncomeRow.weekdayFormatter.string(from: transaction.date))"
        }

        // > 7 days out — show the actual date plus frequency if available
        let dayLabel = IncomeRow.dayFormatter.string(from: transaction.date)
        if let frequency = transaction.incomeSource?.frequency.displayName {
            return "\(frequency) · \(dayLabel)"
        }
        return "Expected \(dayLabel)"
    }

    private var secondaryColor: Color {
        if transaction.incomeStatus == .expected && isPastDue {
            return Theme.terracotta
        }
        return .secondary
    }

    // MARK: - Helpers

    private var displayAmount: Decimal {
        if transaction.incomeStatus == .confirmed {
            return transaction.confirmedAmount ?? transaction.amount
        }
        return transaction.expectedAmount > 0 ? transaction.expectedAmount : transaction.amount
    }

    private var confirmedDate: Date? {
        // Heuristic: confirmed entries store their confirm date in `date`;
        // if the model has a separate `confirmedAt` later, prefer that.
        transaction.incomeStatus == .confirmed ? transaction.date : nil
    }

    private var isPastDue: Bool {
        guard transaction.incomeStatus == .expected else { return false }
        return transaction.date < Calendar.current.startOfDay(for: .now)
    }

    private var accessibilityLabel: String {
        let amount = displayAmount.asPlainCurrency()
        let status = transaction.incomeStatus == .confirmed ? "confirmed" : "expected"
        return "\(transaction.name), \(amount), \(status), \(secondaryText)"
    }

    // MARK: - Formatters

    private static let dayFormatter: DateFormatter = {
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
