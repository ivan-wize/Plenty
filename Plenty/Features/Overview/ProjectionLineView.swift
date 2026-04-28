//
//  ProjectionLineView.swift
//  Plenty
//
//  Target path: Plenty/Features/Overview/ProjectionLineView.swift
//
//  Phase 3 (v2): the secondary line beneath the Overview hero number.
//
//  Shows expected income still to come this month, providing forward
//  context to the live confirmed-only budget number above. Per PDS
//  §4.1: "When confirmed income < projected income for the month:
//  '+ $X expected this month.' When all income is confirmed: hidden."
//
//  When the snapshot also has a `nextIncomeDate`, the copy upgrades to
//  reference that date for warmth: "+ $2,400 expected by Friday."
//

import SwiftUI

struct ProjectionLineView: View {

    let snapshot: PlentySnapshot

    var body: some View {
        if shouldDisplay {
            Text(displayText)
                .font(Typography.Support.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(accessibilityText)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    // MARK: - Display Logic

    private var shouldDisplay: Bool {
        snapshot.expectedIncomeRemaining > 0
    }

    private var displayText: String {
        let amount = snapshot.expectedIncomeRemaining.asPlainCurrency()

        // If we know when, lean into that.
        if let nextDate = snapshot.nextIncomeDate {
            let now = Date.now
            let cal = Calendar.current
            if cal.isDateInToday(nextDate) {
                return "+ \(amount) expected today"
            }
            if cal.isDateInTomorrow(nextDate) {
                return "+ \(amount) expected tomorrow"
            }
            // Within the next 7 days → use weekday
            let days = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: nextDate)).day ?? 0
            if days > 0, days <= 7 {
                let weekday = nextDate.formatted(.dateTime.weekday(.wide))
                return "+ \(amount) expected \(weekday)"
            }
            // Otherwise just say "this month"
            return "+ \(amount) expected this month"
        }

        return "+ \(amount) expected this month"
    }

    private var accessibilityText: String {
        let amount = snapshot.expectedIncomeRemaining.asPlainCurrency()
        return "\(amount) in income still expected this month."
    }
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
