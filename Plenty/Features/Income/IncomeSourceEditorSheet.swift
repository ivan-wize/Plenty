//
//  IncomeSourceEditorSheet.swift
//  Plenty
//
//  Target path: Plenty/Features/Income/IncomeSourceEditorSheet.swift
//
//  Phase 4 (v2): edit an existing IncomeSource template. Surfaced when
//  the user taps an Expected row on the Income tab.
//
//  Editable:
//    • Name
//    • Expected amount
//    • Frequency (weekly / biweekly / semimonthly / monthly)
//    • Day-of-month or weekday (depending on frequency)
//    • Roll over to next month (PDS §4.2 — the per-source toggle)
//    • Active state (deactivate without deleting)
//
//  Destructive:
//    • Delete this source (also purges expected entries via
//      IncomeEntryGenerator.purgeExpectedEntries)
//
//  Save behavior: writes back to the IncomeSource and triggers an
//  IncomeEntryGenerator pass for the current month so changes
//  propagate immediately. Future months pick up the new values when
//  they're scoped via the MonthNavigator.
//

import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.plenty.app", category: "income-source-editor")

struct IncomeSourceEditorSheet: View {

    @Bindable var source: IncomeSource

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showingDeleteConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                amountSection
                nameSection
                cadenceSection
                rolloverSection
                statusSection
                deleteSection
            }
            .navigationTitle("Edit income")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .confirmationDialog(
                "Delete \(source.name)?",
                isPresented: $showingDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete and remove expected entries", role: .destructive) {
                    deleteSource()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Confirmed entries from this source stay as historical record. Future expected entries will be removed.")
            }
        }
    }

    // MARK: - Amount

    private var amountSection: some View {
        Section {
            HStack {
                Text("$")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                CurrencyField(value: $source.expectedAmount, prompt: "0", accent: Theme.sage)
            }
        } header: {
            Text("Amount")
        }
    }

    // MARK: - Name

    private var nameSection: some View {
        Section("Name") {
            TextField("e.g. Paycheck", text: $source.name)
                .textInputAutocapitalization(.words)
        }
    }

    // MARK: - Cadence

    @ViewBuilder
    private var cadenceSection: some View {
        Section {
            Picker("Frequency", selection: $source.frequency) {
                ForEach(IncomeSource.Frequency.allCases) { freq in
                    Text(freq.displayName).tag(freq)
                }
            }

            switch source.frequency {
            case .monthly:
                Stepper(value: $source.dayOfMonth, in: 1...31) {
                    HStack {
                        Text("Day")
                        Spacer()
                        Text(source.dayOfMonth.ordinalString)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }

            case .semimonthly:
                Stepper(value: $source.dayOfMonth, in: 1...31) {
                    HStack {
                        Text("First day")
                        Spacer()
                        Text(source.dayOfMonth.ordinalString)
                            .foregroundStyle(.secondary)
                    }
                }
                Stepper(
                    value: Binding(
                        get: { source.secondDayOfMonth ?? 15 },
                        set: { source.secondDayOfMonth = $0 }
                    ),
                    in: 1...31
                ) {
                    HStack {
                        Text("Second day")
                        Spacer()
                        Text((source.secondDayOfMonth ?? 15).ordinalString)
                            .foregroundStyle(.secondary)
                    }
                }

            case .weekly, .biweekly:
                Picker("Pay day", selection: $source.weekday) {
                    Text("Sunday").tag(0)
                    Text("Monday").tag(1)
                    Text("Tuesday").tag(2)
                    Text("Wednesday").tag(3)
                    Text("Thursday").tag(4)
                    Text("Friday").tag(5)
                    Text("Saturday").tag(6)
                }
            }
        } header: {
            Text("When")
        }
    }

    // MARK: - Rollover

    private var rolloverSection: some View {
        Section {
            Toggle("Roll over to next month", isOn: $source.rolloverEnabled)
                .tint(Theme.sage)
        } footer: {
            Text(source.rolloverEnabled
                 ? "New months will automatically include expected entries from this source."
                 : "This source is dormant. Use 'Copy from last month' on the Income tab to bring it forward when you want to.")
        }
    }

    // MARK: - Status

    private var statusSection: some View {
        Section {
            Toggle("Active", isOn: $source.isActive)
                .tint(Theme.sage)
        } footer: {
            Text(source.isActive
                 ? "This source generates expected income."
                 : "Deactivated. No new expected entries are created. Confirmed entries stay as historical record.")
        }
    }

    // MARK: - Delete

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showingDeleteConfirm = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete source")
                }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Cancel", role: .cancel) { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("Save") { saveAndRegenerate() }
                .fontWeight(.semibold)
                .disabled(source.name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    // MARK: - Actions

    private func saveAndRegenerate() {
        source.updatedAt = .now
        try? modelContext.save()

        // Regenerate the current month so the user sees their edits
        // reflected immediately. Generator is idempotent.
        let cal = Calendar.current
        let now = Date.now
        let m = cal.component(.month, from: now)
        let y = cal.component(.year, from: now)

        do {
            try IncomeEntryGenerator(context: modelContext).prepareExpectedEntries(month: m, year: y)
        } catch {
            logger.error("Income source regenerate failed: \(error.localizedDescription)")
        }

        dismiss()
    }

    private func deleteSource() {
        do {
            // Remove expected entries first; confirmed entries are
            // preserved by the generator's purge logic.
            try IncomeEntryGenerator(context: modelContext).purgeExpectedEntries(for: source)
        } catch {
            logger.error("Purge expected entries failed: \(error.localizedDescription)")
        }

        modelContext.delete(source)
        try? modelContext.save()
        dismiss()
    }
}
