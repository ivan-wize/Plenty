//
//  SettingsView.swift
//  Plenty
//
//  Target path: Plenty/Features/Settings/SettingsView.swift
//
//  Phase 0 (v2): renamed from SettingsTab.swift. Ready for sheet
//  presentation from OverviewTopBar's gear button (wired in P3).
//
//  Changes from v1:
//    • No longer a tab — RootView presents this in a NavigationStack
//      sheet when AppState.showingSettingsSheet is true.
//    • IncomeSourcesView reference removed — income management lives
//      in the Income tab now (P4).
//    • Toolbar gets a Done button to dismiss the sheet.
//
//  Sections retained in v2:
//    • Appearance
//    • Notifications
//    • Plenty Pro (purchase / restore)
//    • Import (CSV)
//    • Privacy & Data
//    • About
//

import SwiftUI

struct SettingsView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var showingImportSheet = false

    var body: some View {
        Form {
            AppearanceSection()
            NotificationsSection()
            PlentyProSection()

            Section {
                Button {
                    showingImportSheet = true
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                            .foregroundStyle(.secondary)
                            .frame(width: 28)
                        Text("Import from CSV")
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } header: {
                Text("Data")
            } footer: {
                Text("Import past transactions from a CSV file. Your data stays on this device and in your private iCloud.")
            }

            PrivacyAndDataSection()
            AboutSection()
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
                    .fontWeight(.semibold)
            }
        }
        .sheet(isPresented: $showingImportSheet) {
            ImportCSVSheet()
        }
    }
}
