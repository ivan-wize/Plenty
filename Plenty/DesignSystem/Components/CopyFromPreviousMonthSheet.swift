//
//  CopyFromPreviousMonthSheet.swift
//  Plenty
//
//  Target path: Plenty/DesignSystem/Components/CopyFromPreviousMonthSheet.swift
//
//  Phase 4 (v2): the generic copy-from-previous-month sheet used by:
//    • Income tab (P4) — copy expected/confirmed income templates
//    • Expenses tab → Bills (P5) — copy bills from the previous month
//
//  Pattern (PDS §4.2 / §4.3):
//    1. Sheet shows every item from the source set, each with a
//       checkbox (default: all selected)
//    2. Each row has an editable amount inline so users can tune
//       before copying (rent went up, etc.)
//    3. Toolbar primary action shows the count: "Copy 4 items"
//    4. Cancel returns without inserting anything
//
//  The component is generic over `Source: Identifiable & Hashable` so
//  call sites pass their own model type (Transaction in v2). The
//  `summarize` closure projects the source into display-ready info,
//  and the `onCopy` closure receives the user's selection plus any
//  amount overrides — call sites materialize the new records on their
//  side.
//

import SwiftUI

// MARK: - Item Summary

struct CopyItemSummary: Hashable {
    let name: String
    let defaultAmount: Decimal
    let secondary: String?

    init(name: String, defaultAmount: Decimal, secondary: String? = nil) {
        self.name = name
        self.defaultAmount = defaultAmount
        self.secondary = secondary
    }
}

// MARK: - Selection

struct CopySelection<Source: Identifiable> {
    let source: Source
    let amount: Decimal
}

// MARK: - Sheet

struct CopyFromPreviousMonthSheet<Source: Identifiable & Hashable>: View where Source.ID: Hashable {

    let title: String
    let subtitle: String?
    let sourceItems: [Source]
    let summarize: (Source) -> CopyItemSummary
    let onCopy: ([CopySelection<Source>]) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedIDs: Set<Source.ID> = []
    @State private var amountOverrides: [Source.ID: Decimal] = [:]
    @State private var didInitialize = false

    var body: some View {
        NavigationStack {
            content
                .background(Theme.background)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
        }
        .onAppear {
            guard !didInitialize else { return }
            // Default state: select every item with its original amount.
            selectedIDs = Set(sourceItems.map(\.id))
            for item in sourceItems {
                amountOverrides[item.id] = summarize(item).defaultAmount
            }
            didInitialize = true
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if sourceItems.isEmpty {
            ContentUnavailableView {
                Label("Nothing to copy", systemImage: "tray")
            } description: {
                Text("There were no entries in the previous month.")
            }
        } else {
            list
        }
    }

    private var list: some View {
        List {
            if let subtitle {
                Section {
                    Text(subtitle)
                        .font(Typography.Support.footnote)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }

            Section {
                Button { selectAll() } label: {
                    Text(allSelected ? "Deselect all" : "Select all")
                        .font(Typography.Support.footnote)
                        .foregroundStyle(Theme.sage)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .padding(.bottom, -8)
            }

            Section {
                ForEach(sourceItems) { item in
                    row(for: item)
                }
            } footer: {
                Text("Selected entries will be added to the current month. You can edit each amount inline.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Row

    private func row(for item: Source) -> some View {
        let summary = summarize(item)
        let isSelected = selectedIDs.contains(item.id)

        return HStack(spacing: 12) {
            checkbox(isSelected: isSelected) {
                toggle(item)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(summary.name)
                    .font(Typography.Body.regular)
                    .foregroundStyle(isSelected ? .primary : .secondary)

                if let secondary = summary.secondary {
                    Text(secondary)
                        .font(Typography.Support.footnote)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 8)

            CurrencyField(
                value: Binding(
                    get: { amountOverrides[item.id] ?? summary.defaultAmount },
                    set: { amountOverrides[item.id] = $0 }
                ),
                prompt: "0",
                accent: Theme.sage
            )
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 100)
            .opacity(isSelected ? 1.0 : 0.4)
            .disabled(!isSelected)
        }
        .contentShape(Rectangle())
        .onTapGesture { toggle(item) }
    }

    private func checkbox(isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? AnyShapeStyle(Theme.sage) : AnyShapeStyle(HierarchicalShapeStyle.tertiary))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 28, height: 28)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSelected ? "Selected" : "Not selected")
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Cancel", role: .cancel) { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(actionTitle) {
                applyAndDismiss()
            }
            .fontWeight(.semibold)
            .disabled(selectedIDs.isEmpty)
        }
    }

    private var actionTitle: String {
        let count = selectedIDs.count
        switch count {
        case 0:  return "Copy"
        case 1:  return "Copy 1 item"
        default: return "Copy \(count) items"
        }
    }

    // MARK: - Actions

    private var allSelected: Bool {
        !sourceItems.isEmpty && selectedIDs.count == sourceItems.count
    }

    private func selectAll() {
        if allSelected {
            selectedIDs.removeAll()
        } else {
            selectedIDs = Set(sourceItems.map(\.id))
        }
    }

    private func toggle(_ item: Source) {
        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
        } else {
            selectedIDs.insert(item.id)
        }
    }

    private func applyAndDismiss() {
        let selections: [CopySelection<Source>] = sourceItems.compactMap { item in
            guard selectedIDs.contains(item.id) else { return nil }
            let amount = amountOverrides[item.id] ?? summarize(item).defaultAmount
            return CopySelection(source: item, amount: amount)
        }
        onCopy(selections)
        dismiss()
    }
}
