//
//  LiquidGlassTabBar.swift
//  Plenty
//
//  Target path: Plenty/DesignSystem/LiquidGlassTabBar.swift
//
//  Phase 4.x polish (post-launch v1): two visual fixes so the bar
//  reads as Liquid Glass against Plenty's cream background.
//
//  1. The four tab buttons live inside a `GlassEffectContainer`, so
//     when the selected indicator's matched geometry animates between
//     tabs, the underlying glass refraction follows the move rather
//     than rebuilding at the new position. This is the same pattern
//     Apple's Activity, Music, and Fitness tab bars use.
//
//  2. The selected indicator opacity bumps from 0.22 → 0.32 and gains
//     a hairline stroke at sage 0.40. On Plenty's cream surface, the
//     prior 0.22 fill nearly vanished — the selected tab read as
//     un-selected. The new treatment is visible without being loud.
//
//  Outer-bar padding (insetting from screen edges) lives in RootView,
//  not here — this view stays content-sized so callers can choose how
//  to mount it.
//
//  ----- Earlier history -----
//
//  Phase 0 (v2): four equal tab buttons, no center Add button.
//
//  v1 had five visual elements: Home / Accounts / [Add] / Plan /
//  Settings. v2 simplifies to four equal-weight buttons:
//
//      [Overview] [Income] [Expenses] [Plan]
//
//  The Add affordance moves to:
//    • Overview tab — floating Add button (FAB) bottom-right (P3)
//    • Income / Expenses tabs — toolbar `+` (P4 / P5)
//    • Plan tab — context-specific (Add Account, etc.)
//
//  The active tab animates a sage-tinted capsule indicator behind it via
//  matchedGeometryEffect.
//
//  Background, sizing, and accessibility behavior carry over unchanged.
//

import SwiftUI

struct LiquidGlassTabBar: View {

    // MARK: - Bindings

    @Binding var selectedTab: AppState.Tab

    // MARK: - Animation

    @Namespace private var indicatorNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Layout Constants

    /// Intrinsic height of a tab button content stack (icon + label +
    /// internal padding). Kept as a constant so the bar height remains
    /// predictable across Dynamic Type sizes (the per-button content
    /// gets a fixedSize).
    private static let buttonContentHeight: CGFloat = 52

    // MARK: - Body

    var body: some View {
        GlassEffectContainer(spacing: 0) {
            HStack(spacing: 0) {
                tabButton(.overview)
                tabButton(.income)
                tabButton(.expenses)
                tabButton(.plan)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
        // ONE glass capsule for the entire bar (matches Fitness/Music).
        // `.interactive()` gives the touch-driven specular response.
        .glassEffect(.regular.interactive(), in: Capsule())
        // On light backgrounds glass refraction alone is too subtle —
        // a layered drop-shadow gives the bar visible lift.
        .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 6)
        .shadow(color: Color.black.opacity(0.08), radius: 1, x: 0, y: 1)
    }

    // MARK: - Tab Button

    private func tabButton(_ tab: AppState.Tab) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            guard !isSelected else { return }
            if reduceMotion {
                selectedTab = tab
            } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    selectedTab = tab
                }
            }
        } label: {
            ZStack {
                if isSelected {
                    Capsule()
                        .fill(Theme.sage.opacity(0.32))
                        .overlay(
                            Capsule()
                                .strokeBorder(Theme.sage.opacity(0.40), lineWidth: 0.5)
                        )
                        .matchedGeometryEffect(id: "activeTabIndicator", in: indicatorNamespace)
                }

                VStack(spacing: 3) {
                    Image(systemName: tab.systemImage)
                        .font(.system(size: 20, weight: .medium))
                        .symbolVariant(isSelected ? .fill : .none)
                        .symbolRenderingMode(.hierarchical)

                    Text(tab.title)
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(isSelected ? Theme.sage : Color.secondary)
                .padding(.vertical, 6)
                .padding(.horizontal, 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: Self.buttonContentHeight)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}
