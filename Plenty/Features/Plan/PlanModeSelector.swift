//
//  PlanModeSelector.swift
//  Plenty
//
//  Target path: Plenty/Features/Plan/PlanModeSelector.swift
//
//  Custom three-mode segmented control: Outlook / Save / Trends.
//  Sage tinted active state with matched-geometry animation. Cleaner
//  than .pickerStyle(.segmented) and matches Plenty's design language.
//

import SwiftUI

enum PlanMode: String, CaseIterable, Identifiable, Sendable {
    case outlook, save, trends

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .outlook: return "Outlook"
        case .save:    return "Save"
        case .trends:  return "Trends"
        }
    }

    var iconName: String {
        switch self {
        case .outlook: return "calendar"
        case .save:    return "leaf"
        case .trends:  return "chart.bar"
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
                Button {
                    if reduceMotion {
                        selection = mode
                    } else {
                        withAnimation(.snappy(duration: 0.25)) {
                            selection = mode
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: mode.iconName)
                            .font(.footnote.weight(.medium))
                        Text(mode.displayName)
                            .font(Typography.Body.regular)
                    }
                    .foregroundStyle(selection == mode ? .white : .primary)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .background {
                        if selection == mode {
                            RoundedRectangle(cornerRadius: Theme.Radius.inline, style: .continuous)
                                .fill(Theme.sage)
                                .matchedGeometryEffect(id: "active", in: namespace)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(mode.displayName)
                .accessibilityAddTraits(selection == mode ? .isSelected : [])
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.inline + 2, style: .continuous)
                .fill(Color.secondary.opacity(Theme.Opacity.hairline))
        )
    }
}

#Preview {
    @Previewable @State var mode: PlanMode = .outlook
    return VStack {
        PlanModeSelector(selection: $mode)
            .padding()
        Spacer()
    }
    .background(Theme.background)
}
