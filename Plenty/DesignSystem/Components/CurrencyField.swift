//
//  CurrencyField.swift
//  Plenty
//
//  Target path: Plenty/DesignSystem/CurrencyField.swift
//
//  A decimal-pad text field that binds to a Decimal. Used by every
//  Add/Edit sheet in the app for amount entry.
//
//  Design choices:
//    • Default font is Typography.Hero.compact (28pt rounded medium)
//      to match the "$" that callers render alongside it. Inline call
//      sites that want a smaller treatment override with .font().
//    • Right-aligned by default so currency reads cleanly when paired
//      with a left-aligned label in a Form row. Hero call sites place
//      the field after a "$" in an HStack and the alignment falls out
//      naturally.
//    • Tint drives both the cursor and the selection highlight — set
//      it sage for primary fields, terracotta for destructive money
//      (statement balance, debt principal), .secondary for inline.
//    • A zero value renders as the prompt placeholder rather than "0"
//      so empty fields look empty.
//
//  Locale-aware decimal separator: parses both "." and "," so users
//  in EU locales can type comma-decimals.
//

import SwiftUI

struct CurrencyField: View {

    // MARK: - API

    @Binding var value: Decimal
    let prompt: String
    let accent: Color

    // MARK: - Internal State

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    // MARK: - Body

    var body: some View {
        TextField(
            prompt,
            text: $text,
            prompt: Text(prompt).foregroundStyle(.tertiary)
        )
        .keyboardType(.decimalPad)
        .multilineTextAlignment(.trailing)
        .font(Typography.Hero.compact)
        .monospacedDigit()
        .tint(accent)
        .focused($isFocused)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .onAppear {
            text = displayString(for: value)
        }
        .onChange(of: text) { _, newText in
            commitTextToValue(newText)
        }
        .onChange(of: value) { _, newValue in
            // Only sync from value to text when the user isn't actively
            // typing — otherwise we fight their input.
            if !isFocused {
                let formatted = displayString(for: newValue)
                if formatted != text {
                    text = formatted
                }
            }
        }
        .accessibilityLabel("Amount")
        .accessibilityValue(value == 0 ? "Empty" : value.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))
    }

    // MARK: - Conversion

    private func displayString(for d: Decimal) -> String {
        guard d != 0 else { return "" }
        // Plain numeric string, no thousands separators (the decimal
        // pad doesn't include a comma so users can't type them anyway).
        var copy = d
        var rounded = Decimal.zero
        NSDecimalRound(&rounded, &copy, 2, .plain)

        // Drop trailing .00 for a cleaner display when the value is whole.
        let asDouble = NSDecimalNumber(decimal: rounded).doubleValue
        if asDouble == asDouble.rounded() {
            return String(Int(asDouble))
        }
        return "\(rounded)"
    }

    private func commitTextToValue(_ raw: String) {
        let normalized = raw
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: " ", with: "")

        if normalized.isEmpty {
            if value != 0 { value = 0 }
            return
        }

        if let decimal = Decimal(string: normalized) {
            if decimal != value {
                value = decimal
            }
        }
    }
}

// MARK: - Preview

#Preview("Empty (sage)") {
    StatefulPreview { CurrencyFieldPreviewWrapper(initial: 0, accent: Theme.sage) }
        .padding()
}

#Preview("With value (terracotta)") {
    StatefulPreview { CurrencyFieldPreviewWrapper(initial: 1234.56, accent: Theme.terracotta) }
        .padding()
}

private struct CurrencyFieldPreviewWrapper: View {
    @State private var value: Decimal
    let accent: Color

    init(initial: Decimal, accent: Color) {
        _value = State(initialValue: initial)
        self.accent = accent
    }

    var body: some View {
        HStack {
            Text("$")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            CurrencyField(value: $value, prompt: "0", accent: accent)
        }
    }
}

private struct StatefulPreview<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View { content() }
}
