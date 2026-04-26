//
//  ImportCompleteView.swift
//  Plenty
//
//  Target path: Plenty/Features/Settings/Import/ImportCompleteView.swift
//
//  Final stage of CSV import. Confirms what was imported and skipped.
//  Done button dismisses the sheet.
//

import SwiftUI

struct ImportCompleteView: View {

    let imported: Int
    let skipped: Int
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72, weight: .light))
                .foregroundStyle(Theme.sage)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 8) {
                Text(headlineText)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                if skipped > 0 {
                    Text("\(skipped) row\(skipped == 1 ? "" : "s") skipped.")
                        .font(Typography.Body.regular)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(action: onDone) {
                HStack {
                    Spacer()
                    Text("Done")
                        .font(Typography.Body.emphasis)
                    Spacer()
                }
                .padding(.vertical, 14)
            }
            .background(Theme.sage)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    private var headlineText: String {
        if imported == 0 {
            return "Nothing imported."
        }
        if imported == 1 {
            return "Imported 1 transaction."
        }
        return "Imported \(imported) transactions."
    }
}

#Preview("Success") {
    ImportCompleteView(imported: 47, skipped: 3) {}
}

#Preview("Nothing") {
    ImportCompleteView(imported: 0, skipped: 12) {}
}
