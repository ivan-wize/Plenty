//
//  PlanModeSelector.swift
//  Plenty
//
//  Target path: Plenty/Features/Plan/PlanModeSelector.swift
//
//  Phase 6 (v2): four segments now — Accounts (free), Outlook (Pro),
//  Save (Pro), Trends (Pro). Accounts becomes the default mode when
//  the user lands on Plan, giving free users an immediately usable
//  surface here for the first time.
//
//  Layout decisions for the four-segment width:
//    • Icons stay alongside the labels — at 4 segments the labels
//      are still legible on iPhone Mini width (~85pt per segment).
//    • The matched-geometry indicator slides between any pair of
//      segments smoothly, so flipping between Pro modes feels
//      identical to flipping between Pro and Accounts.
//

import SwiftUI

enum PlanMode: String, CaseIterable, Identifiable, Sendable {
    case accounts
    case outlook
    case save
    case trends

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .accounts: return "Accounts"
        case .outlook:  return "Outlook"
        case .save:     return "Save"
        case .trends:   return "Trends"
        }
    }

    var iconName: String {
        switch self {
        case .accounts: return "building.columns"
        case .outlook:  return "calendar"
        case .save:     return "leaf"
        case .trends:   return "chart.bar"
        }
    }

    /// True when this mode is gated behind Plenty Pro. Accounts is the
    /// only free mode under the v2 Plan tab.
    var requiresPro: Bool {
        switch self {
        case .accounts:                 return false
        case .outlook, .save, .trends:  return true
        }
    }
}

struct PlanModeSelector: View {

    @Binding var selection: PlanMode

    @Namespace private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            ForEach(PlanMode.allCases) { mode in
                segment(for: mode)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.inline + 2, style: .continuous)
                .fill(Color.secondary.opacity(Theme.Opacity.hairline))
        )
    }

    private func segment(for mode: PlanMode) -> some View {
        let isSelected = selection == mode

        return Button {
            if reduceMotion {
                selection = mode
            } else {
                withAnimation(.snappy(duration: 0.25)) {
                    selection = mode
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: mode.iconName)
                    .font(.footnote.weight(.medium))
                Text(mode.displayName)
                    .font(Typography.Body.regular)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: Theme.Radius.inline, style: .continuous)
                        .fill(Theme.sage)
                        .matchedGeometryEffect(id: "active", in: namespace)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    @Previewable @State var mode: PlanMode = .accounts
    return VStack {
        PlanModeSelector(selection: $mode)
            .padding()
        Spacer()
    }
    .background(Theme.background)
}
