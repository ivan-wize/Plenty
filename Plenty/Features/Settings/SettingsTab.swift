//
//  SettingsTab.swift
//  Plenty
//
//  Target path: Plenty/Features/Settings/SettingsTab.swift
//
//  Phase 2: AppearanceSection + AboutSection only.
//  Phase 7: + NotificationsSection + Income Sources nav.
//  Phase 8: + Import from CSV row.
//

import SwiftUI

struct SettingsTab: View {

    @State private var showingImport = false

    var body: some View {
        NavigationStack {
            Form {
                NotificationsSection()

                financialDataSection

                AppearanceSection()

                AboutSection()
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingImport) {
                ImportCSVSheet()
            }
        }
    }

    // MARK: - Financial Data Section

    private var financialDataSection: some View {
        Section {
            NavigationLink {
                IncomeSourcesView()
            } label: {
                Label("Income Sources", systemImage: "arrow.down.circle")
            }

            Button {
                showingImport = true
            } label: {
                Label("Import from CSV", systemImage: "doc.badge.arrow.up")
                    .foregroundStyle(.primary)
            }
        } header: {
            Text("Financial Data")
        }
    }
}
