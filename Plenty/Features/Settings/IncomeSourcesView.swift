//
//  IncomeSourcesView.swift
//  Plenty
//
//  Target path: Plenty/Features/Settings/IncomeSourcesView.swift
//
//  Lists income sources (active and inactive). Each row shows name,
//  amount, cadence. Tap to open edit sheet (AddIncomeSheet wrapper).
//  Swipe actions: deactivate (or reactivate), delete.
//
//  Reached from SettingsTab → "Income Sources" row.
//

import SwiftUI
import SwiftData

struct IncomeSourcesView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @Query(sort: \IncomeSource.name) private var allSources: [IncomeSource]

    private var activeSources: [IncomeSource] {
        allSources.filter(\.isActive)
    }

    private var inactiveSources: [IncomeSource] {
        allSources.filter { !$0.isActive }
    }

    // MARK: - Body

    var body: some View {
        Group {
            if allSources.isEmpty {
                ContentUnavailableView {
                    Label("No income sources", systemImage: "arrow.down.circle")
                } description: {
                    Text("Add a paycheck from the Add menu to set up recurring income.")
                } actions: {
                    Button {
                        appState.pendingAddSheet = .income(preferRecurring: true)
                    } label: {
                        Text("Add a paycheck").fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.sage)
                }
            } else {
                List {
                    if !activeSources.isEmpty {
                        Section("Active") {
                            ForEach(activeSources) { source in
                                row(for: source)
                            }
                            .onDelete { indexSet in delete(at: indexSet, in: activeSources) }
                        }
                    }

                    if !inactiveSources.isEmpty {
                        Section("Inactive") {
                            ForEach(inactiveSources) { source in
                                row(for: source)
                                    .opacity(0.7)
                            }
                            .onDelete { indexSet in delete(at: indexSet, in: inactiveSources) }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Income Sources")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    appState.pendingAddSheet = .income(preferRecurring: true)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    // MARK: - Row

    private func row(for source: IncomeSource) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "arrow.down.circle")
                .font(.body.weight(.medium))
                .foregroundStyle(source.isActive ? Theme.sage : .secondary)
                .frame(width: 36, height: 36)
                .background(
                    Circle().fill((source.isActive ? Theme.sage : .secondary).opacity(Theme.Opacity.soft))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(source.name)
                    .font(Typography.Body.regular)
                    .foregroundStyle(.primary)

                Text(cadenceLine(for: source))
                    .font(Typography.Support.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(source.expectedAmount.asPlainCurrency())
                .font(Typography.Body.emphasis.monospacedDigit())
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                modelContext.delete(source)
                try? modelContext.save()
            } label: {
                Label("Delete", systemImage: "trash")
            }

            Button {
                source.isActive.toggle()
                try? modelContext.save()
            } label: {
                if source.isActive {
                    Label("Pause", systemImage: "pause.circle")
                } else {
                    Label("Reactivate", systemImage: "play.circle")
                }
            }
            .tint(Theme.amber)
        }
    }

    // MARK: - Helpers

    private func cadenceLine(for source: IncomeSource) -> String {
        switch source.frequency {
        case .monthly:
            return "Monthly on the \((source.dayOfMonth ?? 1).ordinal)"
        case .semimonthly:
            return "Twice monthly"
        case .biweekly:
            return "Every other week"
        case .weekly:
            return "Weekly"
        }
    }

    private func delete(at offsets: IndexSet, in sources: [IncomeSource]) {
        for index in offsets {
            modelContext.delete(sources[index])
        }
        try? modelContext.save()
    }
}

private extension Decimal {
    func asPlainCurrency() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "$\(self)"
    }
}
