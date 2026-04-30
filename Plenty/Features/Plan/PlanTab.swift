//
//  PlanTab.swift
//  Plenty
//
//  Target path: Plenty/Features/Plan/PlanTab.swift
//
//  Phase 2.2 (post-launch v1): the conditional `+` toolbar button
//  (visible on Accounts mode only) is removed. Adding an account
//  remains a contextual action surfaced two ways inside
//  PlanAccountsView itself:
//
//    • The empty-state CTA when no accounts exist
//    • The `plus.circle` icon next to the "Accounts" header
//
//  The root-level AddFloatingButton offers the standard menu
//  (transaction, bill, income, scan) without an "Add account" item
//  — surfacing it there would compete with the contextual affordance
//  the user is already looking at.
//
//  ----- Earlier history -----
//
//  Phase 6 (v2): four-mode Plan tab. Accounts is the new free
//  default; Outlook, Save, and Trends remain Pro.
//
//  Layout:
//    1. PlanModeSelector (4 segments)
//    2. Mode content:
//       - Accounts → PlanAccountsView (always free)
//       - Outlook  → OutlookView or PlanLockedView(lockedMode: .outlook)
//       - Save     → SaveView or PlanLockedView(lockedMode: .save)
//       - Trends   → TrendsView or PlanLockedView(lockedMode: .trends)
//
//  Default mode: .accounts. v1 defaulted to .outlook because Plan
//  was Pro-only; in v2 the default reflects what a free user can
//  actually use without unlocking.
//

import SwiftUI

struct PlanTab: View {

    @Environment(AppState.self) private var appState

    @State private var mode: PlanMode = .accounts

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                PlanModeSelector(selection: $mode)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 12)

                modeContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Theme.background)
            .navigationTitle("Plan")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Mode Content

    @ViewBuilder
    private var modeContent: some View {
        switch mode {
        case .accounts:
            PlanAccountsView()

        case .outlook:
            if appState.isProUnlocked {
                OutlookView()
            } else {
                PlanLockedView(lockedMode: .outlook)
            }

        case .save:
            if appState.isProUnlocked {
                SaveView()
            } else {
                PlanLockedView(lockedMode: .save)
            }

        case .trends:
            if appState.isProUnlocked {
                TrendsView()
            } else {
                PlanLockedView(lockedMode: .trends)
            }
        }
    }
}
