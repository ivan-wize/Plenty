//
//  Wordmark.swift
//  Plenty
//
//  Target path: Plenty/DesignSystem/Wordmark.swift
//
//  The Plenty wordmark.
//
//  Rules locked by PRD §4.1:
//    • Always "Plenty". Title case. No period. No punctuation.
//    • Always SF Pro Display, Medium weight (500).
//    • Tracking: -1.5% at display sizes (48pt and above), -0.5% at text sizes.
//    • Three color modes:
//        - `.brand`        standalone (brand-forward): Plenty Sage
//        - `.lockupLight`  in an icon+wordmark lockup on a light surface: Charcoal
//        - `.lockupDark`   in an icon+wordmark lockup on a dark surface: Off-white
//
//  Never tilt, skew, outline, shadow, or gradient. Never wrap in a box,
//  badge, or pill. Never use a weight other than Medium. Never reintroduce
//  a period. These are brand rules, not style preferences.
//

import SwiftUI

// MARK: - Wordmark

struct Wordmark: View {

    // MARK: - Mode

    enum Mode {
        /// Brand-forward: sage on any background. The default.
        case brand
        /// Icon+wordmark lockup on a light surface. Charcoal fill.
        case lockupLight
        /// Icon+wordmark lockup on a dark surface. Off-white fill.
        case lockupDark
    }

    // MARK: - Size

    /// Fixed point size for the wordmark. Use a case that matches the
    /// surface rather than raw numbers.
    enum Size {
        /// Marketing hero, splash. 72pt.
        case marketing
        /// On-screen hero, e.g. onboarding. 48pt.
        case display
        /// Section title, nav title. 28pt.
        case title
        /// Inline body text. 17pt.
        case headline
        /// Small inline use, e.g. footer. 13pt.
        case footnote

        fileprivate var pointSize: CGFloat {
            switch self {
            case .marketing: return 72
            case .display:   return 48
            case .title:     return 28
            case .headline:  return 17
            case .footnote:  return 13
            }
        }
    }

    // MARK: - Properties

    let size: Size
    let mode: Mode

    // MARK: - Init

    init(_ size: Size = .display, mode: Mode = .brand) {
        self.size = size
        self.mode = mode
    }

    // MARK: - Body

    var body: some View {
        Text("Plenty")
            .font(.system(size: size.pointSize, weight: .medium, design: .default))
            .tracking(opticalTracking)
            .foregroundStyle(fill)
            .accessibilityLabel("Plenty")
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Derived

    /// Tracking in points, computed from the point size per PRD §4.1.
    /// Display sizes (48pt+) get -1.5%; smaller sizes get -0.5%.
    private var opticalTracking: CGFloat {
        let pt = size.pointSize
        let rate: CGFloat = pt >= 48 ? -0.015 : -0.005
        return pt * rate
    }

    /// The foreground fill. Sage / Charcoal / Off-white per mode.
    private var fill: Color {
        switch mode {
        case .brand:       return Theme.sage
        case .lockupLight: return Theme.charcoal
        case .lockupDark:  return Theme.offWhite
        }
    }
}

// MARK: - Previews

#Preview("Sizes") {
    VStack(alignment: .leading, spacing: 24) {
        Wordmark(.marketing)
        Wordmark(.display)
        Wordmark(.title)
        Wordmark(.headline)
        Wordmark(.footnote)
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.background)
}

#Preview("Modes") {
    VStack(spacing: 32) {
        Wordmark(.display, mode: .brand)
            .padding(32)
            .frame(maxWidth: .infinity)
            .background(Theme.background)

        Wordmark(.display, mode: .lockupLight)
            .padding(32)
            .frame(maxWidth: .infinity)
            .background(Theme.offWhite)

        Wordmark(.display, mode: .lockupDark)
            .padding(32)
            .frame(maxWidth: .infinity)
            .background(Theme.charcoal)
    }
}
