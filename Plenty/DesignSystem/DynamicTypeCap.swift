//
//  DynamicTypeCap.swift
//  Plenty
//
//  Target path: Plenty/DesignSystem/DynamicTypeCap.swift
//
//  View modifier that caps Dynamic Type at a specific size for
//  layouts that break at extreme accessibility sizes. Most of Plenty
//  scales fully through AX5; this is reserved for compact regions
//  where unbounded scaling would push content off screen:
//
//    • Hero number with tabular monospaced digits (caps at AX3)
//    • Inline currency in row layouts (caps at AX3)
//    • Lock screen widget views (system already caps these)
//
//  The user's overall Dynamic Type setting is preserved everywhere
//  else; this modifier only narrows the range for these specific
//  surfaces. The cap is set high enough (AX3) to still serve users
//  who depend on accessibility sizes.
//

import SwiftUI

extension View {

    /// Cap dynamic type at the given size. Use for compact layouts
    /// that need a ceiling.
    func dynamicTypeCap(_ size: DynamicTypeSize = .accessibility3) -> some View {
        self.dynamicTypeSize(...size)
    }

    /// Cap dynamic type at AX3, the most common cap for monetary
    /// displays in Plenty.
    func currencyDynamicTypeCap() -> some View {
        self.dynamicTypeSize(...DynamicTypeSize.accessibility3)
    }
}
