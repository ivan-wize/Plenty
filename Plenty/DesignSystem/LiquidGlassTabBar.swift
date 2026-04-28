//
//  LiquidGlassTabBar.swift
//  Plenty
//
//  Target path: Plenty/DesignSystem/LiquidGlassTabBar.swift
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
    private static let buttonContentHeight: CGFloat = 44

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.overview)
            tabButton(.income)
            tabButton(.expenses)
            tabButton(.plan)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        // Crucial: collapse vertical sizing to content. Without this
        // the bar can stretch to fill the safe-area inset region and
        // the capsule background grows to dominate the screen.
        .fixedSize(horizontal: false, vertical: true)
        .modifier(GlassCapsuleBackground())
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
                        .fill(Theme.sage.opacity(Theme.Opacity.soft))
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
            // Constrain the per-button frame so the inner Capsule
            // (the selected-state indicator) doesn't stretch beyond
            // the button's natural content size.
            .frame(height: Self.buttonContentHeight)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

// MARK: - Glass Capsule Background

/// Encapsulates the bar's background treatment so the swap to native
/// Liquid Glass (when the framework lands a stable API) is one place.
private struct GlassCapsuleBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}
