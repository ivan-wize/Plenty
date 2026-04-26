//
//  ProBadge.swift
//  Plenty
//
//  Target path: Plenty/Pro/ProBadge.swift
//
//  Tiny "Pro" capsule badge. Used to mark Pro-gated features in shared
//  surfaces (PlanLockedView preview tiles, future Settings entries
//  for Pro-only options).
//

import SwiftUI

struct ProBadge: View {

    var body: some View {
        Text("Pro")
            .font(.caption2.weight(.bold))
            .foregroundStyle(Theme.sage)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(Theme.sage.opacity(Theme.Opacity.soft))
            )
    }
}

#Preview {
    HStack {
        Text("Outlook")
            .font(Typography.Body.emphasis)
        ProBadge()
    }
    .padding()
    .background(Theme.background)
}
