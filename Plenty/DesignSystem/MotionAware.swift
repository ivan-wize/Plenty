//
//  MotionAware.swift
//  Plenty
//
//  Target path: Plenty/DesignSystem/MotionAware.swift
//
//  Centralizes the "respect Reduce Motion" pattern. Most of Plenty's
//  animations are subtle and serve information density (snappy spring
//  on hero number changes, opacity fades on TheRead, matched geometry
//  on PlanModeSelector). All of them should disable when the user has
//  Reduce Motion enabled.
//
//  Without this helper, every view needs:
//
//      @Environment(\.accessibilityReduceMotion) private var reduceMotion
//      ...
//      .animation(reduceMotion ? nil : .snappy, value: someValue)
//
//  With this helper:
//
//      .motionAwareAnimation(.snappy, value: someValue)
//

import SwiftUI

extension View {

    /// Apply the given animation only when Reduce Motion is off.
    /// Mirrors the standard `.animation(_:value:)` modifier.
    func motionAwareAnimation<V: Equatable>(
        _ animation: Animation?,
        value: V
    ) -> some View {
        self.modifier(MotionAwareAnimationModifier(animation: animation, value: value))
    }

    /// Apply the given transition only when Reduce Motion is off.
    /// Falls back to .identity (no transition) when motion is reduced.
    func motionAwareTransition(_ transition: AnyTransition) -> some View {
        self.modifier(MotionAwareTransitionModifier(transition: transition))
    }
}

// MARK: - Animation Modifier

private struct MotionAwareAnimationModifier<V: Equatable>: ViewModifier {

    let animation: Animation?
    let value: V

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

// MARK: - Transition Modifier

private struct MotionAwareTransitionModifier: ViewModifier {

    let transition: AnyTransition

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.transition(reduceMotion ? .identity : transition)
    }
}
