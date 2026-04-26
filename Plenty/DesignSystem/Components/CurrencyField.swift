//
//  CurrencyField.swift
//  Plenty
//
//  Target path: Plenty/DesignSystem/CurrencyField.swift
//
//  A reusable currency input. Binds to a Decimal, accepts digit-only
//  entry through the decimalPad keyboard, and renders a formatted
//  currency display. Caller controls the prompt and accent color.
//
//  Used by every Add/Edit sheet that takes an amount. Centralizes the
//  Decimal ↔ String conversion so each sheet doesn't reinvent it.
//

import SwiftUI

struct CurrencyField: View {

    @Binding var value: Decimal
    var prompt: String = "Amount"
    var accent: Color = Theme.sage

    @FocusState private var isFocused: Bool
    @State private var rawText: String = ""

    var body: some View {
        TextField(prompt, text: $rawText)
            .font(.system(size: 28, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
            .keyboardType(.decimalPad)
            .focused($isFocused)
            .foregroundStyle(value > 0 ? accent : .primary)
            .onAppear {
                rawText = formatForEditing(value)
            }
            .onChange(of: rawText) { _, newText in
                value = parseDecimal(from: newText)
            }
            .onChange(of: value) { _, newValue in
                // External changes (like reset on save) should reflect
                // back into the field.
                let formatted = formatForEditing(newValue)
                if formatted != rawText {
                    rawText = formatted
                }
            }
    }

    // MARK: - Formatting

    private func formatForEditing(_ value: Decimal) -> String {
        if value == 0 { return "" }
        return value.description
    }

    private func parseDecimal(from text: String) -> Decimal {
        let cleaned = text.filter { $0.isNumber || $0 == "." }
        return Decimal(string: cleaned) ?? 0
    }
}

#Preview {
    @Previewable @State var amount: Decimal = 0
    return Form {
        CurrencyField(value: $amount, prompt: "Amount")
    }
}
