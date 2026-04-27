//
//  LiquidGlassTabBar.swift
//  Plenty
//
//  Target path: Plenty/DesignSystem/LiquidGlassTabBar.swift
//
//  The floating tab bar. Four tabs laid out as:
//
//      [Home] [Accounts]  (Add)  [Plan] [Settings]
//
//  The Add button is visually distinct per PRD §8: a raised sage circle
//  with a white plus glyph. The four tab buttons are icon + label; the
//  active tab animates a sage-tinted capsule indicator behind it via
//  matchedGeometryEffect.
//
//  Background treatment:
//    • Uses `.background(.ultraThinMaterial, in: Capsule())` — a
//      well-defined SwiftUI API that produces predictable sizing.
//    • Earlier revisions tried iOS 26's `glassEffect(_:in:)` directly,
//      but that modifier renders unexpectedly large here because it
//      treats the supplied shape as the glass surface region rather
//      than clipping to the view's frame. To re-enable native Liquid
//      Glass later, wrap this bar in a `GlassEffectContainer` and
//      swap the modifier in `GlassCapsuleBackground` below.
//
//  Sizing:
//    • The bar applies `.fixedSize(horizontal: false, vertical: true)`
//      so it fills the available width inside its safe-area inset but
//      collapses vertically to its intrinsic content height. Without
//      this, the bar can be vertically stretched by the inset region
//      and the capsule background grows to dominate the screen.
//
//  Accessibility:
//    • Each tab has an accessibilityLabel; active state sets .isSelected.
//    • Add button hints at what it opens.
//    • Sensory feedback fires on every selection.
//
//  Respects Reduce Motion: the capsule indicator teleports rather than
//  animating when the accessibility toggle is on.
//

import SwiftUI

struct LiquidGlassTabBar: View {

    // MARK: - Bindings

    @Binding var selectedTab: AppState.Tab
    let onAddTapped: () -> Void

    // MARK: - Animation

    @Namespace private var indicatorNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Layout Constants

    /// Intrinsic height of a tab button content stack (icon + label +
    /// internal padding). The Add button (52pt) is the tallest element
    /// and is what actually defines the bar's vertical extent, but we
    /// keep this constant so the bar height remains predictable across
    /// Dynamic Type sizes (the per-button content gets a fixedSize).
    private static let buttonContentHeight: CGFloat = 44

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.home)
            tabButton(.accounts)

            addButton

            tabButton(.plan)
            tabButton(.settings)
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
            // Constrain the per-button frame so the inner Capsule (the
            // selected-state indicator) doesn't stretch beyond the
            // button's natural content size.
            .frame(height: Self.buttonContentHeight)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    // MARK: - Add Button

    private var addButton: some View {
        Button(action: onAddTapped) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(
                    Circle()
                        .fill(Theme.sage)
                )
                .shadow(color: Theme.sage.opacity(0.35), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
        .accessibilityLabel("Add")
        .accessibilityHint("Add an expense, income, or bill")
        .sensoryFeedback(.impact(weight: .medium), trigger: false)
    }
}

// MARK: - Glass Capsule Background
//
// Isolated so the exact background API lives in one place. To re-enable
// native iOS 26 Liquid Glass later, wrap the entire bar in a
// `GlassEffectContainer` and swap this modifier's body to:
//
//     content.glassEffect(.regular, in: Capsule())
//
// Doing so without a container caused the bar to render at full screen
// size in earlier revisions, which is why we ship the material fallback
// by default.

private struct GlassCapsuleBackground: ViewModifier {

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Previews

#Preview("Light") {
    StatefulPreviewWrapper(AppState.Tab.home) { binding in
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack {
                Spacer()
                LiquidGlassTabBar(
                    selectedTab: binding,
                    onAddTapped: {}
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    StatefulPreviewWrapper(AppState.Tab.plan) { binding in
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack {
                Spacer()
                LiquidGlassTabBar(
                    selectedTab: binding,
                    onAddTapped: {}
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }
    .preferredColorScheme(.dark)
}

// MARK: - Preview Helper

/// Lets previews hold their own state without needing an outer @State.
private struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State private var value: Value
    let content: (Binding<Value>) -> Content

    init(_ initial: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        self._value = State(initialValue: initial)
        self.content = content
    }

    var body: some View { content($value) }
}
