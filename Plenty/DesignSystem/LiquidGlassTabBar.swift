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
//  Liquid Glass treatment:
//    • Bar capsule uses `glassEffect(_:in:)` (iOS 26 API).
//    • If the exact signature differs in your SDK, swap the modifier
//      in `glassCapsule()` below; it's the only call site.
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
// Isolated so the exact iOS 26 API lives in one place. If the signature
// differs in your SDK build, adjust here only.

private struct GlassCapsuleBackground: ViewModifier {

    func body(content: Content) -> some View {
        // Preferred: iOS 26 Liquid Glass.
        // If `glassEffect(_:in:)` is unavailable in your SDK build,
        // replace the body of this function with:
        //
        //     content.background(.ultraThinMaterial, in: Capsule())
        //
        // The visual difference is small and the call sites don't change.
        content
            .glassEffect(.regular, in: Capsule())
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
