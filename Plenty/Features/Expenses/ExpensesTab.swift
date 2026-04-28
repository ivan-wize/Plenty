//
//  ExpensesTab.swift
//  Plenty
//
//  Target path: Plenty/Features/Expenses/ExpensesTab.swift
//
//  Phase 2 (v2): MonthNavigator wired. Body remains a placeholder
//  until P5 ships the segmented control, the scoped Transactions /
//  Bills sub-views, and the document scanning routing.
//

import SwiftUI

struct ExpensesTab: View {

    @Environment(MonthScope.self) private var monthScope

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MonthNavigator()
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                    .padding(.bottom, 12)

                ContentUnavailableView {
                    Label("Expenses", systemImage: "arrow.up.circle")
                        .foregroundStyle(Theme.sage)
                } description: {
                    VStack(spacing: 8) {
                        Text("Coming in Phase 5.")
                        Text("Scoped to \(monthScope.displayLabel)")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()
            }
            .background(Theme.background)
            .navigationTitle("Expenses")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
