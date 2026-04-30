//
//  OverviewTopBar.swift
//  Plenty
//
//  Target path: Plenty/Features/Overview/OverviewTopBar.swift
//
//  Phase 3.2 (post-launch v1): adds an ellipsis menu in the trailing
//  group containing "Share this month." The gear button (Settings)
//  stays as a direct one-tap affordance — Settings is a frequent
//  destination and demoting it to a menu item would be a regression.
//
//  Toolbar layout after this change:
//
//    Leading:   [Info]
//    Trailing:  [Ellipsis Menu]  [Gear]
//
//  The ellipsis Menu is the home for low-frequency actions that
//  shouldn't crowd the bar. Today: Share. Future overflow items
//  (Export, Print, etc.) can live there too.
//
//  ----- Earlier history -----
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
    @Binding var showingShareSheet: Bool

    /// True when the user has any data worth sharing. When false, the
    /// share menu item disables itself with a quiet hint instead of
    /// disappearing — discoverability stays consistent.
    let canShare: Bool

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
            Menu {
                Button {
                    showingShareSheet = true
                } label: {
                    Label("Share this month", systemImage: "square.and.arrow.up")
                }
                .disabled(!canShare)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Theme.sage)
                    .symbolRenderingMode(.hierarchical)
            }
            .accessibilityLabel("More actions")
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
