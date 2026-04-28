//
//  InlineLockScreenView.swift
//  Plenty
//
//  Target path: PlentyWidget/Views/InlineLockScreenView.swift
//
//  Phase 8 (v2): inline string moves from "spendable" / "past your
//  margin" to "left this month" / "over budget."
//
//  Inline lock screen widget. Sits above the clock as a single line.
//  Limited to ~50 characters and no formatting other than what
//  WidgetKit allows for accessoryInline.
//

import SwiftUI
import WidgetKit

struct InlineLockScreenView: View {

    let entry: PlentyEntry

    var body: some View {
        if entry.isUnavailable {
            Text("Plenty: open the app to refresh")
        } else {
            Text(lineText)
        }
    }

    private var lineText: String {
        let amountString = formattedAmount
        if entry.isOverBudget {
            return "\(amountString) over budget"
        }
        return "\(amountString) left this month"
    }

    private var formattedAmount: String {
        let abs = entry.monthlyBudgetRemaining < 0
            ? -entry.monthlyBudgetRemaining
            : entry.monthlyBudgetRemaining
        let value = NSDecimalNumber(decimal: abs).doubleValue
        let formatted: String
        if value >= 1_000 {
            formatted = String(format: "$%.1fk", value / 1_000)
        } else {
            formatted = String(format: "$%.0f", value)
        }
        return entry.isOverBudget ? "−\(formatted)" : formatted
    }
}
