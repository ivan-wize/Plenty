//
//  ExpensesSegmentedControl.swift
//  Plenty
//
//  Target path: Plenty/Features/Expenses/ExpensesSegmentedControl.swift
//
//  Phase 5 (v2): the Transactions / Bills segmented control at the
//  top of the Expenses tab.
//
//  Custom-built rather than .pickerStyle(.segmented) so the visual
//  language matches Plenty's other in-app selectors (PlanModeSelector,
//  AppearanceSection rows): rounded sage-tinted indicator under the
//  selected segment, animated with matchedGeometryEffect.
//

import SwiftUI

enum ExpensesSubTab: String, CaseIterable, Identifiable, Hashable {
    case transactions
    case bills

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .transactions: return "Transactions"
        case .bills:        return "Bills"
        }
    }

    var iconName: String {
        switch self {
        case .transactions: return "creditcard"
        case .bills:        return "doc.text"
        }
    }
}

struct ExpensesSegmentedControl: View {

    @Binding var selection: ExpensesSubTab
    @Namespace private var indicator

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ExpensesSubTab.allCases) { tab in
                segment(tab)
            }
        }
        .padding(4)
        .background(
            Capsule(style: .continuous)
                .fill(Theme.cardSurface)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.secondary.opacity(Theme.Opacity.hairline), lineWidth: 0.5)
        )
        .accessibilityElement(children: .contain)
    }

    private func segment(_ tab: ExpensesSubTab) -> some View {
        let isSelected = selection == tab

        return Button {
            withAnimation(reduceMotion ? nil : .snappy) {
                selection = tab
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.iconName)
                    .font(.footnote.weight(.medium))
                Text(tab.displayName)
                    .font(Typography.Body.regular)
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    if isSelected {
                        Capsule(style: .continuous)
                            .fill(Theme.sage)
                            .matchedGeometryEffect(id: "selection", in: indicator)
                    }
                }
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}
