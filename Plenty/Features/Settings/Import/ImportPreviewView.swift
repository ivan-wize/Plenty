//
//  ImportPreviewView.swift
//  Plenty
//
//  Target path: Plenty/Features/Settings/Import/ImportPreviewView.swift
//
//  Third stage of CSV import. Lists all candidates with per-row
//  inclusion checkboxes, summary header (counts and toggles), filter
//  chips for narrowing the view (All / Issues / Duplicates).
//
//  Tap a row to toggle inclusion. Bottom action button commits the
//  selection.
//

import SwiftUI

struct ImportPreviewView: View {

    @Bindable var session: CSVImportSession
    let onCommit: () -> Void

    @State private var filter: PreviewFilter = .all

    enum PreviewFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case issues = "Issues"
        case duplicates = "Duplicates"

        var id: String { rawValue }
    }

    private var filteredCandidates: [CSVImportSession.Candidate] {
        switch filter {
        case .all:
            return session.candidates
        case .issues:
            return session.candidates.filter { $0.parseError != nil }
        case .duplicates:
            return session.candidates.filter { c in
                if case .exactDuplicate = c.dedupeStatus { return true }
                if case .nearMatch = c.dedupeStatus { return true }
                return false
            }
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            summaryCard
            filterChips
            list
        }
        .safeAreaInset(edge: .bottom) {
            commitButton
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.bar)
        }
    }

    // MARK: - Summary

    private var summaryCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                summaryStat(
                    label: "Importing",
                    value: session.includedCount,
                    color: Theme.sage
                )
                summaryStat(
                    label: "Skipping",
                    value: session.excludedCount,
                    color: .secondary
                )
                if session.dedupeCount > 0 {
                    summaryStat(
                        label: "Duplicates",
                        value: session.dedupeCount,
                        color: Theme.amber
                    )
                }
                if session.errorCount > 0 {
                    summaryStat(
                        label: "Issues",
                        value: session.errorCount,
                        color: Theme.terracotta
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Theme.cardSurface)
    }

    private func summaryStat(label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
            Text(label)
                .font(Typography.Support.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PreviewFilter.allCases) { f in
                    chip(for: f)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Theme.background)
    }

    private func chip(for f: PreviewFilter) -> some View {
        Button {
            filter = f
        } label: {
            HStack(spacing: 4) {
                Text(f.rawValue)
                    .font(Typography.Body.regular)
                let count = filteredCount(for: f)
                Text("(\(count))")
                    .font(Typography.Support.footnote)
                    .foregroundStyle(filter == f ? .white.opacity(0.8) : .secondary)
            }
            .foregroundStyle(filter == f ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(filter == f ? Theme.sage : Color.secondary.opacity(Theme.Opacity.hairline))
            )
        }
        .buttonStyle(.plain)
    }

    private func filteredCount(for f: PreviewFilter) -> Int {
        switch f {
        case .all: return session.candidates.count
        case .issues: return session.candidates.filter { $0.parseError != nil }.count
        case .duplicates:
            return session.candidates.filter { c in
                if case .exactDuplicate = c.dedupeStatus { return true }
                if case .nearMatch = c.dedupeStatus { return true }
                return false
            }.count
        }
    }

    // MARK: - List

    private var list: some View {
        List {
            ForEach(filteredCandidates) { candidate in
                row(for: candidate)
            }
        }
        .listStyle(.plain)
    }

    private func row(for candidate: CSVImportSession.Candidate) -> some View {
        Button {
            toggleInclusion(candidate)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: candidate.include ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(candidate.include ? Theme.sage : .tertiary)
                    .symbolRenderingMode(.hierarchical)

                VStack(alignment: .leading, spacing: 2) {
                    Text(candidate.name)
                        .font(Typography.Body.regular)
                        .foregroundStyle(candidate.include ? .primary : .secondary)
                        .strikethrough(!candidate.include, color: .secondary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(formattedDate(candidate.date))
                            .font(Typography.Support.footnote)
                            .foregroundStyle(.secondary)

                        if let category = candidate.category {
                            Text("· \(category.displayName)")
                                .font(Typography.Support.footnote)
                                .foregroundStyle(.secondary)
                        }

                        statusBadge(for: candidate)
                    }
                }

                Spacer()

                Text(formattedAmount(candidate))
                    .font(Typography.Body.emphasis.monospacedDigit())
                    .foregroundStyle(amountColor(for: candidate))
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func statusBadge(for candidate: CSVImportSession.Candidate) -> some View {
        switch candidate.dedupeStatus {
        case .unique:
            EmptyView()
        case .exactDuplicate:
            Text("· Exact dupe")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.amber)
        case .nearMatch(_, let reason):
            Text("· \(reason)")
                .font(.caption2)
                .foregroundStyle(Theme.amber)
                .lineLimit(1)
        }
    }

    private func formattedAmount(_ candidate: CSVImportSession.Candidate) -> String {
        let formatted = candidate.amount.asPlainCurrency()
        switch candidate.kind {
        case .income:
            return "+\(formatted)"
        default:
            return "−\(formatted)"
        }
    }

    private func amountColor(for candidate: CSVImportSession.Candidate) -> Color {
        if !candidate.include { return .secondary }
        switch candidate.kind {
        case .income: return Theme.sage
        default: return .primary
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    // MARK: - Commit

    private var commitButton: some View {
        Button(action: onCommit) {
            HStack {
                Spacer()
                Text(session.includedCount > 0
                     ? "Import \(session.includedCount) Transactions"
                     : "Nothing to import")
                    .font(Typography.Body.emphasis)
                Spacer()
            }
            .padding(.vertical, 14)
        }
        .background(session.includedCount > 0 ? Theme.sage : Color.secondary.opacity(0.4))
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .disabled(session.includedCount == 0)
    }

    // MARK: - Actions

    private func toggleInclusion(_ candidate: CSVImportSession.Candidate) {
        guard let index = session.candidates.firstIndex(where: { $0.id == candidate.id }) else { return }
        session.candidates[index].include.toggle()
    }
}

private extension Decimal {
    func asPlainCurrency() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "$\(self)"
    }
}
