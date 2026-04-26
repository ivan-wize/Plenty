//
//  InlineLockScreenView.swift
//  Plenty
//
//  Target path: PlentyWidget/Views/InlineLockScreenView.swift
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
        if entry.zone == .over {
            return "\(amountString) past your margin"
        }
        return "\(amountString) spendable"
    }

    private var formattedAmount: String {
        let abs = entry.spendable < 0 ? -entry.spendable : entry.spendable
        let value = NSDecimalNumber(decimal: abs).doubleValue
        let formatted: String
        if value >= 1_000 {
            formatted = String(format: "$%.1fk", value / 1_000)
        } else {
            formatted = String(format: "$%.0f", value)
        }
        return entry.spendable < 0 ? "−\(formatted)" : formatted
    }
}
