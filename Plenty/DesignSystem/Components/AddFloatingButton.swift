//
//  AddFloatingButton.swift
//  Plenty
//
//  Target path: Plenty/DesignSystem/Components/AddFloatingButton.swift
//
//  Phase 5 (v2): three-item menu now that the document scanner can
//  route a captured page to the right editor automatically.
//
//  Menu actions (PDS §4.1):
//    • Add transaction → AppState.pendingAddSheet = .expense
//    • Add bill        → AppState.pendingAddSheet = .bill()
//    • Scan document   → presents DocumentScannerView (mode: .auto),
//                        on finish flips AppState.pendingAddSheet to
//                        .expenseFromScan / .billFromScan / .expense
//                        depending on the result.
//

import SwiftUI

struct AddFloatingButton: View {

    @Environment(AppState.self) private var appState

    /// Diameter of the circular button. 56pt matches Apple's spec for
    /// floating action buttons.
    var size: CGFloat = 56

    @State private var showingScanner = false

    var body: some View {
        Menu {
            Button {
                appState.pendingAddSheet = .expense
            } label: {
                Label("Add transaction", systemImage: "creditcard")
            }

            Button {
                appState.pendingAddSheet = .bill()
            } label: {
                Label("Add bill", systemImage: "doc.text")
            }

            Button {
                showingScanner = true
            } label: {
                Label("Scan document", systemImage: "doc.viewfinder")
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(Theme.sage)
                        .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add")
        .accessibilityHint("Add a transaction, add a bill, or scan a document.")
        .sensoryFeedback(.impact(weight: .medium), trigger: appState.pendingAddSheet?.id)
        .sheet(isPresented: $showingScanner) {
            DocumentScannerView(mode: .auto) { result in
                handleScannerResult(result)
            }
            .ignoresSafeArea()
        }
    }

    private func handleScannerResult(_ result: DocumentScanResult) {
        switch result {
        case .receipt(let draft, let image):
            appState.pendingAddSheet = .expenseFromScan(draft, image)
        case .bill(let draft, let image):
            appState.pendingAddSheet = .billFromScan(draft, image)
        case .manual(let image):
            // AI didn't classify confidently. Default to expense, but
            // attach the image so the user has it.
            if let image {
                let blank = ReceiptDraft(merchant: nil, totalAmount: nil, date: nil, category: nil)
                appState.pendingAddSheet = .expenseFromScan(blank, image)
            } else {
                appState.pendingAddSheet = .expense
            }
        case .cancelled:
            break
        }
    }
}
