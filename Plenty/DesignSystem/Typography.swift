//
//  Typography.swift
//  Plenty
//
//  Target path: Plenty/DesignSystem/Typography.swift
//
//  Centralized type ramp. Single source of truth for every text style
//  in the app. Per PRD §4.4:
//
//    • SF Pro Display  → ≥ 20pt (titles, hero numbers, section headers)
//    • SF Pro Text     → < 20pt (body, list rows, secondary labels)
//    • SF Pro Rounded  → currency values only, wherever they appear
//
//  SwiftUI's `.system(_:design:weight:)` automatically selects Display
//  vs Text based on the resolved point size, so we don't need to pick
//  faces by hand — the design parameter only controls Default vs
//  Rounded vs Mono.
//
//  Weight conventions (PRD §4.4):
//    • Hero currency display          → .medium    (500)
//    • Headlines and section titles   → .semibold  (600)
//    • Body copy                      → .regular   (400)
//    • Emphasis within body           → .medium    (500)
//
//  Never use weights below .regular or above .semibold in production.
//
//  All tokens are built on Dynamic Type text styles (`.title`, `.body`,
//  `.footnote`, etc.) rather than fixed point sizes, so the type ramp
//  scales fully with the user's preferred text size up to AX5 (PRD §4.4).
//  Call sites that need fixed sizes (Hero number on Home) opt out
//  locally with `.font(.system(size: 64, ...))`.
//
//  Migration path: any future custom typeface drops in here behind the
//  same call-site API. No view code changes.
//

import SwiftUI

// MARK: - Typography Namespace

enum Typography {

    // MARK: Hero

    /// Large rounded display used for inline currency editors and
    /// secondary hero numerals. Approximately 28pt at default Dynamic
    /// Type size, scales with the user's preferred text size.
    /// Call sites: `CurrencyField`.
    enum Hero {
        static let compact: Font = .system(.title, design: .rounded, weight: .medium)
    }

    // MARK: Titles (SF Pro Display, semibold)

    /// Section titles inside cards and sheets.
    enum Title {
        /// ~22pt at default Dynamic Type size. Used for prominent section
        /// headers (e.g. Onboarding step titles).
        static let medium: Font = .system(.title2, design: .default, weight: .semibold)
        /// ~20pt at default Dynamic Type size. The workhorse section
        /// header — used by Save, Trends, Outlook, Debt cards, etc.
        static let small: Font = .system(.title3, design: .default, weight: .semibold)
    }

    // MARK: Body (SF Pro Text)

    /// Body copy and list row primary text.
    enum Body {
        /// 17pt body. The default text style for paragraph copy and
        /// transaction row names.
        static let regular: Font = .system(.body, design: .default, weight: .regular)
        /// 17pt medium. Use for emphasis within body — primary value
        /// props, button labels, key callouts.
        static let emphasis: Font = .system(.body, design: .default, weight: .medium)
    }

    // MARK: Currency (SF Pro Rounded — currency only, per PRD §4.4)

    /// Currency values inside list rows. Pairs naturally with
    /// `.monospacedDigit()` at the call site for column alignment.
    enum Currency {
        static let row: Font = .system(.body, design: .rounded, weight: .medium)
    }

    // MARK: Support (SF Pro Text — small)

    /// Secondary, label, and metadata copy.
    enum Support {
        /// ~13pt medium. Use for column headers and small label chips
        /// where slight weight aids scanability.
        static let label: Font = .system(.footnote, design: .default, weight: .medium)
        /// ~13pt regular. Default for sub-row metadata, helper text,
        /// and footer copy beneath inputs.
        static let footnote: Font = .system(.footnote, design: .default, weight: .regular)
        /// ~12pt regular. The smallest size used in the app — chart
        /// axis labels, fine-print disclaimers, badge text.
        static let caption: Font = .system(.caption, design: .default, weight: .regular)
    }
}
