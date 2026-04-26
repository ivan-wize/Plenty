//
//  PlanTab.swift
//  Plenty
//
//  Target path: Plenty/Features/Plan/PlanTab.swift
//
//  The Plan tab. Phase 6: replaces the Phase 2 stub with the real
//  three-mode tab gated behind Pro.
//
//  Locked: PlanLockedView with paywall presentation.
//  Unlocked: PlanModeSelector + active mode (OutlookView | SaveView | TrendsView).
//

import SwiftUI

struct PlanTab: View {

    @Environment(AppState.self) private var appState

    @State private var mode: PlanMode = .outlook

    var body: some View {
        NavigationStack {
            Group {
                if appState.isProUnlocked {
                    unlockedContent
                } else {
                    PlanLockedView()
                }
            }
            .background(Theme.background)
            .navigationTitle("Plan")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Unlocked Content

    private var unlockedContent: some View {
        VStack(spacing: 0) {
            PlanModeSelector(selection: $mode)
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 12)

            modeContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var modeContent: some View {
        switch mode {
        case .outlook: OutlookView()
        case .save:    SaveView()
        case .trends:  TrendsView()
        }
    }
}
