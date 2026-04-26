//
//  Theme.swift
//  Plenty
//
//  Target path: Plenty/DesignSystem/Theme.swift
//
//  Central design tokens. Single source of truth for the brand palette,
//  state colors, corner radii, opacity scale, and the two recurring
//  view patterns (section header, card background).
//
//  Every color in this file comes from PRD Section 4.3. Five brand colors
//  total. Any additional color in the codebase requires product approval.
//
//  Colors are defined as adaptive UIColor closures rather than asset
//  catalog color sets so the app builds without pre-authored Contents.json
//  files. The sage / amber / terracotta brand colors are identical in
//  Light and Dark; only the background and card surfaces adapt.
//
//  Migration path: these can move to an Assets.xcassets color catalog
//  with zero call-site changes, since `Theme.sage` etc. are the public
//  API. Adapter swap only.
//

import SwiftUI
import UIKit

// MARK: - Theme Namespace

enum Theme {

    // MARK: Brand palette (PRD §4.3)

    /// The primary brand color. `#6B8E7F`. Used for the Add button, active
    /// tab indicator, positive currency amounts, chart primary lines, and
    /// occasional brand accents. Appears sparingly by design.
    static let sage = Color(uiColor: UIColor(red: 0x6B / 255.0,
                                             green: 0x8E / 255.0,
                                             blue: 0x7F / 255.0,
                                             alpha: 1.0))

    /// Warning state, approaching-short. `#D4A656`. Reserved for state
    /// communication, never decorative.
    static let amber = Color(uiColor: UIColor(red: 0xD4 / 255.0,
                                              green: 0xA6 / 255.0,
                                              blue: 0x56 / 255.0,
                                              alpha: 1.0))

    /// Negative state, short or over-budget. `#B55A4A`. Reserved for state
    /// communication, never decorative.
    static let terracotta = Color(uiColor: UIColor(red: 0xB5 / 255.0,
                                                   green: 0x5A / 255.0,
                                                   blue: 0x4A / 255.0,
                                                   alpha: 1.0))

    /// Warm off-white, the interior background in Light mode. `#FAF7F2`.
    static let offWhite = Color(uiColor: UIColor(red: 0xFA / 255.0,
                                                 green: 0xF7 / 255.0,
                                                 blue: 0xF2 / 255.0,
                                                 alpha: 1.0))

    /// Warm charcoal, the interior background in Dark mode. `#1A1C1B`.
    static let charcoal = Color(uiColor: UIColor(red: 0x1A / 255.0,
                                                 green: 0x1C / 255.0,
                                                 blue: 0x1B / 255.0,
                                                 alpha: 1.0))

    // MARK: Adaptive surfaces

    /// The app's interior background. Off-white in Light, charcoal in Dark.
    /// Apply to the root of every screen inside the tab bar.
    static let background = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x1A / 255.0, green: 0x1C / 255.0, blue: 0x1B / 255.0, alpha: 1.0)
            : UIColor(red: 0xFA / 255.0, green: 0xF7 / 255.0, blue: 0xF2 / 255.0, alpha: 1.0)
    })

    /// Card surface that sits cleanly on the interior background. Pure
    /// white in Light mode per PRD §4.3; slightly-lifted charcoal in Dark.
    static let cardSurface = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x23 / 255.0, green: 0x26 / 255.0, blue: 0x25 / 255.0, alpha: 1.0)
            : UIColor(white: 1.0, alpha: 1.0)
    })

    /// Divider color. `#E8E5DE` in Light, lightened charcoal in Dark.
    static let divider = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x2C / 255.0, green: 0x2F / 255.0, blue: 0x2E / 255.0, alpha: 1.0)
            : UIColor(red: 0xE8 / 255.0, green: 0xE5 / 255.0, blue: 0xDE / 255.0, alpha: 1.0)
    })

    // MARK: Corner Radii
    //
    // Three values. Holding the line at three prevents the "is it 12, 14,
    // or 16" drift that Left's audit caught. If a new surface needs a
    // different radius, it probably isn't a card.

    enum Radius {
        /// Chips, tags, inline controls. 10pt.
        static let inline: CGFloat = 10
        /// Standard card or section background. 14pt.
        static let card: CGFloat = 14
        /// Prominent surfaces: hero, modal content. 20pt.
        static let prominent: CGFloat = 20
    }

    // MARK: Opacity Scale
    //
    // Four named values. Reach for one of these before inventing a new one.

    enum Opacity {
        /// Barely-there tint for very subtle fills.
        static let hairline: Double = 0.06
        /// Light tint for pill or chip backgrounds.
        static let soft: Double = 0.12
        /// Noticeable tint for active or selected states.
        static let medium: Double = 0.25
        /// Strong tint, close to the source color.
        static let strong: Double = 0.60
    }
}

// MARK: - View Modifiers

extension View {

    /// Applies the canonical section-header text style: subheadline,
    /// semibold weight, secondary foreground. Apply to the `Text` view
    /// of a header label, not the surrounding container.
    func sectionHeaderStyle() -> some View {
        self
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    /// Standard card background used across Home, Accounts, Plan.
    /// Pass a custom radius only when the surface isn't a standard card.
    func cardBackground(cornerRadius: CGFloat = Theme.Radius.card) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Theme.cardSurface)
        )
    }
}
