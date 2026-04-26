//
//  Typography.swift
//  Plenty
//
//  Target path: Plenty/DesignSystem/Typography.swift
//
//  Typography tokens per PRD §4.4. Three typefaces, all Apple-provided:
//
//    • SF Pro Display   headlines, hero numbers, section headers, 20pt+
//    • SF Pro Text      body copy, list rows, secondary labels, <20pt
//    • SF Pro Rounded   currency values only, wherever they appear
//
//  Weight conventions (PRD §4.4):
//    • Hero currency display: Medium (500)
//    • Headlines and section titles: Semibold (600)
//    • Body copy: Regular (400)
//    • Emphasis within body: Medium (500)
//
//  Weights below Regular (400) or above Semibold (600) are not used in
//  production UI. That rule is enforced by convention, not by this file.
//
//  Dynamic Type: every non-hero token is relative (`.title`, `.body`,
//  `.caption`), so it scales through AX5 automatically. Hero tokens are
//  fixed point size by design; apply `.minimumScaleFactor(0.5)` at the
//  call site with a stacked fallback layout at AX3+.
//

import SwiftUI

// MARK: - Typography Namespace

enum Typography {

    // MARK: Hero (SF Pro Rounded, Medium)
    //
    // The big rounded currency display that anchors the Home screen and
    // any full-screen confirmation. Three canonical sizes. Fixed-size by
    // design.

    enum Hero {
        /// In-card hero, e.g. a total inside a section. 28pt.
        static let compact = Font.system(size: 28, weight: .medium, design: .rounded)
        /// Standalone hero on Home. 48pt.
        static let display = Font.system(size: 48, weight: .medium, design: .rounded)
        /// Full-screen confirm moments, e.g. goal completion. 56pt.
        static let spotlight = Font.system(size: 56, weight: .medium, design: .rounded)
    }

    // MARK: Currency (SF Pro Rounded)
    //
    // Smaller currency values: list row amounts, secondary context, glance
    // items. Rounded design for numeric continuity with the hero.

    enum Currency {
        /// Amount on a list row. Semibold for emphasis against row text.
        static let row = Font.system(.body, design: .rounded).weight(.semibold)
        /// Secondary amount, e.g. "of $3,000". Regular weight.
        static let secondary = Font.system(.subheadline, design: .rounded)
        /// Widget medium currency. Fixed 18pt.
        static let widgetMedium = Font.system(size: 18, weight: .semibold, design: .rounded)
    }

    // MARK: Titles (SF Pro Display, Semibold)

    enum Title {
        /// Screen title, e.g. "Accounts". 28pt semibold.
        static let large = Font.system(size: 28, weight: .semibold, design: .default)
        /// Section title above a card group. 22pt semibold.
        static let medium = Font.system(size: 22, weight: .semibold, design: .default)
        /// Small section title. 20pt semibold. Boundary between Display and Text.
        static let small = Font.system(size: 20, weight: .semibold, design: .default)
    }

    // MARK: Body (SF Pro Text)

    enum Body {
        /// Default body copy. Regular weight.
        static let regular = Font.body
        /// Body copy with emphasis (e.g. The Read sentence). Medium weight.
        static let emphasis = Font.body.weight(.medium)
        /// Secondary body, same size as body.
        static let secondary = Font.body
    }

    // MARK: Supporting (SF Pro Text)

    enum Support {
        /// Subheadline, e.g. section labels next to cards.
        static let subheadline = Font.subheadline
        /// Footnote for tertiary metadata.
        static let footnote = Font.footnote
        /// Caption for the smallest supporting text.
        static let caption = Font.caption
    }
}

// MARK: - Font Extensions
//
// Keeps the legacy `.heroAmount()` call shape from Left for any code that
// copies forward, while routing to the new canonical tokens.

extension Font {

    /// The rounded-design currency font used for hero amounts.
    /// Maps to `Typography.Hero` sizes.
    static func heroAmount(_ size: HeroSize = .display) -> Font {
        switch size {
        case .compact:   return Typography.Hero.compact
        case .display:   return Typography.Hero.display
        case .spotlight: return Typography.Hero.spotlight
        }
    }

    enum HeroSize {
        case compact    // 28pt
        case display    // 48pt
        case spotlight  // 56pt
    }
}
