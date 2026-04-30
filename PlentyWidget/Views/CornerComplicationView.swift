//
//  CornerComplicationView.swift
//  Plenty
//
//  Target path: PlentyWidget/Views/CornerComplicationView.swift
//
//  Phase 4.1 (post-launch v1): the watchOS-specific corner
//  complication. Lives in the four corner slots of a watch face.
//
//  Layout pattern for `accessoryCorner`:
//
//    • Inner area (~22pt circle) — small glyph or compact value
//    • widgetLabel — text rendered curved along the watch face edge
//
//  Plenty's choice: leaf glyph in the corner (brand mark, instantly
//  recognizable on a busy watch face), curved label with the
//  compact dollar amount + state. The dollar amount needs more room
//  than the inner circle offers, and the curved label gives that
//  room without forcing tiny type.
//
//  Family availability: `accessoryCorner` is watchOS-only. Declaring
//  it in the iOS widget bundle's supportedFamilies is harmless —
//  iOS filters it out of its lock screen widget gallery. The same
//  view file ships with both targets when the widget extension's
//  supported destinations include Apple Watch.
//

import SwiftUI
import WidgetKit

struct CornerComplicationView: View {

    let entry: PlentyEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()

            cornerGlyph
        }
        .widgetLabel {
            Text(labelText)
        }
    }

    // MARK: - Inner Glyph

    @ViewBuilder
    private var cornerGlyph: some View {
        if entry.isUnavailable {
            Image(systemName: "icloud.slash")
                .font(.system(size: 14, weight: .semibold))
        } else if !entry.hasAnyData {
            Image(systemName: "leaf")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
        } else {
            // Filled when over budget so the watch face's quick read
            // is "something needs attention" before the user's eyes
            // reach the curved label.
            Image(systemName: entry.isOverBudget ? "leaf.fill" : "leaf")
                .font(.system(size: 14, weight: .semibold))
        }
    }

    // MARK: - Curved Label

    /// Compact, single-line text rendered along the watch face edge.
    /// Always under ~12 characters to fit comfortably across all
    /// watch face shapes (Modular, Infograph, Compact).
    private var labelText: String {
        if entry.isUnavailable {
            return "Open app"
        }
        if !entry.hasAnyData {
            return "Set up Plenty"
        }
        return "\(formattedAmount) \(captionText)"
    }

    private var formattedAmount: String {
        let abs = entry.monthlyBudgetRemaining < 0
            ? -entry.monthlyBudgetRemaining
            : entry.monthlyBudgetRemaining
        let value = NSDecimalNumber(decimal: abs).doubleValue
        let formatted: String
        if value >= 1_000_000 {
            formatted = String(format: "$%.1fM", value / 1_000_000)
        } else if value >= 1_000 {
            formatted = String(format: "$%.1fk", value / 1_000)
        } else {
            formatted = String(format: "$%.0f", value)
        }
        return entry.isOverBudget ? "−\(formatted)" : formatted
    }

    private var captionText: String {
        entry.isOverBudget ? "over" : "left"
    }
}
