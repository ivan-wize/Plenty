//
//  IncomeTab.swift
//  Plenty
//
//  Target path: Plenty/Features/Income/IncomeTab.swift
//
//  Phase 2 (v2): MonthNavigator wired. Body remains a placeholder
//  until P4 ships the income list, summary card, copy-from-last-month,
//  and rollover toggle UI.
//

import SwiftUI

struct IncomeTab: View {

    @Environment(MonthScope.self) private var monthScope

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MonthNavigator()
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                    .padding(.bottom, 12)

                ContentUnavailableView {
                    Label("Income", systemImage: "arrow.down.circle")
                        .foregroundStyle(Theme.sage)
                } description: {
                    VStack(spacing: 8) {
                        Text("Coming in Phase 4.")
                        Text("Scoped to \(monthScope.displayLabel)")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()
            }
            .background(Theme.background)
            .navigationTitle("Income")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
