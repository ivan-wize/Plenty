//
//  AddSubscriptionSheet.swift
//  Plenty
//
//  Target path: Plenty/Features/Add/AddSubscriptionSheet.swift
//
//  Manual subscription entry. User specifies merchant, typical amount,
//  cadence (weekly/monthly/annual), and optionally the next charge date.
//
//  Created with state = .confirmed since the user is adding it
//  intentionally. The Phase 7 detection pipeline creates with .suggested
//  for things it finds in transaction history.
//

import SwiftUI
import SwiftData

struct AddSubscriptionSheet: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var merchantName: String = ""
    @State private var amount: Decimal = 0
    @State private var cadence: Subscription.Cadence = .monthly
    @State private var nextChargeDate: Date = .now
    @State private var hasNextDate: Bool = true

    @FocusState private var nameFocused: Bool

    private var canSave: Bool {
        amount > 0 && !merchantName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                merchantSection
                amountSection
                cadenceSection
                nextChargeSection
            }
            .navigationTitle("Add Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .onAppear { nameFocused = true }
        }
    }

    // MARK: - Sections

    private var merchantSection: some View {
        Section("Merchant") {
            TextField("e.g. Netflix, Spotify, NYT", text: $merchantName)
                .textInputAutocapitalization(.words)
                .focused($nameFocused)
        }
    }

    private var amountSection: some View {
        Section {
            HStack {
                Text("$")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                CurrencyField(value: $amount, prompt: "0", accent: Theme.sage)
            }
        } header: {
            Text(amountLabel)
        }
    }

    private var cadenceSection: some View {
        Section("Cadence") {
            Picker("Cadence", selection: $cadence) {
                ForEach(Subscription.Cadence.allCases) { cadence in
                    Text(cadence.displayName).tag(cadence)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var nextChargeSection: some View {
        Section {
            Toggle("Set next charge date", isOn: $hasNextDate)
            if hasNextDate {
                DatePicker("Next charge", selection: $nextChargeDate, in: Date.now..., displayedComponents: .date)
            }
        } footer: {
            if hasNextDate {
                Text("Plenty uses this to estimate when you'll next be charged.")
                    .font(Typography.Support.caption)
            } else {
                Text("Plenty will start tracking once it sees a matching charge.")
                    .font(Typography.Support.caption)
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
            Button("Add") { save() }
                .fontWeight(.semibold)
                .disabled(!canSave)
        }
    }

    // MARK: - Save

    private func save() {
        let trimmed = merchantName.trimmingCharacters(in: .whitespaces)
        let new = Subscription(
            merchantName: trimmed,
            rawMerchantPattern: trimmed.lowercased(),
            typicalAmount: amount,
            cadence: cadence,
            nextChargeDate: hasNextDate ? nextChargeDate : nil,
            lastChargeDate: nil,
            state: .confirmed
        )
        modelContext.insert(new)
        try? modelContext.save()
        dismiss()
    }

    // MARK: - Labels

    private var amountLabel: String {
        switch cadence {
        case .weekly:  return "Per week"
        case .monthly: return "Per month"
        case .annual:  return "Per year"
        }
    }
}
