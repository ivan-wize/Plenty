//
//  CircularLockScreenView.swift
//  Plenty
//
//  Target path: PlentyWidget/Views/CircularLockScreenView.swift
//
//  Lock screen circular widget. Tiny target — show one number and a
//  one-word label. Uses AccessoryWidgetBackground for legibility on
//  arbitrary wallpapers.
//

import SwiftUI
import WidgetKit

struct CircularLockScreenView: View {

    let entry: PlentyEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()

            if entry.isUnavailable {
                Image(systemName: "icloud.slash")
                    .font(.system(size: 16, weight: .semibold))
            } else {
                VStack(spacing: 1) {
                    Text(formattedAmount)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .monospacedDigit()
                    Text("spendable")
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var formattedAmount: String {
        let value = NSDecimalNumber(decimal: entry.spendable).doubleValue
        let absValue = abs(value)
        let formatted: String
        if absValue >= 1_000_000 {
            formatted = String(format: "$%.1fM", absValue / 1_000_000)
        } else if absValue >= 1_000 {
            formatted = String(format: "$%.1fk", absValue / 1_000)
        } else {
            formatted = String(format: "$%.0f", absValue)
        }
        return value < 0 ? "−\(formatted)" : formatted
    }
}
