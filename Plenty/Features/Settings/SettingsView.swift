//
//  SettingsTab.swift
//  Plenty
//
//  Target path: Plenty/Features/Settings/SettingsTab.swift
//
//  Replaces the prior SettingsTab to include two new sections:
//
//    • PlentyProSection      — surfaces Pro state, restore flow
//    • PrivacyAndDataSection — restates the privacy promise and
//                              provides the destructive Erase button
//
//  Section order, top to bottom: Plenty Pro (most prominent for the
//  monetization gate), Notifications (functional toggles), Financial
//  Data (CSV + income sources), Appearance, Privacy & Data, About.
//
//  Privacy comes near the bottom because it's a "trust restate"
//  rather than a daily action. About sits last as the least
//  frequently visited.
//

import SwiftUI

struct SettingsTab: View {

    @State private var showingImport = false

    var body: some View {
        NavigationStack {
            Form {
                PlentyProSection()

                NotificationsSection()

                financialDataSection

                AppearanceSection()

                PrivacyAndDataSection()

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
