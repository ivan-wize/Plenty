//
//  AddFloatingButton.swift
//  Plenty
//
//  Target path: Plenty/DesignSystem/Components/AddFloatingButton.swift
//
//  Phase 2 (v2): the floating Add button on Overview.
//
//  A round sage circle with a white "+" glyph, positioned in the
//  bottom-right of the Overview tab (PDS §4.1). Tapping opens a Menu
//  with two actions: Add transaction / Add bill. Both route through
//  AppState.pendingAddSheet so RootView's existing pending-sheet
//  router presents the right editor.
//
//  The third PDS-mentioned action ("Scan receipt") is reachable from
//  inside the AddExpenseSheet's existing receipt section. P5 will add
//  a direct scan-first flow that pre-fills the sheet from the
//  captured receipt; for now the FAB stays clean with two primary
//  paths.
//
//  The button respects the floating tab bar's safe-area inset — the
//  caller is expected to position it with its own padding so it
//  clears the tab bar.
//

import SwiftUI

struct AddFloatingButton: View {

    @Environment(AppState.self) private var appState

    /// Diameter of the circular button. 56pt matches Apple's spec for
    /// floating action buttons and the v1 raised tab-bar add button.
    var size: CGFloat = 56

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
        .accessibilityHint("Add a transaction or a bill.")
        .sensoryFeedback(.impact(weight: .medium), trigger: appState.pendingAddSheet?.id)
    }
}
