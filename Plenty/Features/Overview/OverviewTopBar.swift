//
//  OverviewTopBar.swift
//  Plenty
//
//  Target path: Plenty/Features/Overview/OverviewTopBar.swift
//
//  Phase 3 (v2): the Overview tab's top bar — info button on the left,
//  settings button on the right (PDS §4.1).
//
//  Implemented as a `ToolbarContent` struct so OverviewTab can plug it
//  in via `.toolbar { OverviewTopBar(...) }`. The info button drives
//  a local @State on OverviewTab; the settings button flips
//  `appState.showingSettingsSheet`, which RootView observes and
//  presents.
//

import SwiftUI

struct OverviewTopBar: ToolbarContent {

    @Environment(AppState.self) private var appState

    @Binding var showingExplainer: Bool

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showingExplainer = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Theme.sage)
                    .symbolRenderingMode(.hierarchical)
            }
            .accessibilityLabel("About Plenty")
            .accessibilityHint("Learn how the app works.")
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                appState.showingSettingsSheet = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Theme.sage)
                    .symbolRenderingMode(.hierarchical)
            }
            .accessibilityLabel("Settings")
        }
    }
}
