//
//  UpdateBalanceSheet.swift
//  Plenty
//
//  Target path: Plenty/Features/Accounts/UpdateBalanceSheet.swift
//
//  Quick balance update for an existing account. The single most common
//  account interaction. Logs an AccountBalance snapshot so the trend
//  chart in AccountDetailView gains a new point.
//
//  Compact sheet at .medium detent. Just the account name, a currency
//  field, and Save. Optional note for the snapshot.
//

import SwiftUI
import SwiftData

struct UpdateBalanceSheet: View {

    let account: Account

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var newBalance: Decimal
    @State private var note: String = ""
    @FocusState private var amountFocused: Bool

    init(account: Account) {
        self.account = account
        self._newBalance = State(initialValue: account.balance)
    }

    private var hasChanged: Bool { newBalance != account.balance }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: account.category.iconName)
                            .foregroundStyle(.secondary)
                        Text(account.name)
                            .font(Typography.Body.regular)
                        Spacer()
                    }
                }

                Section {
                    HStack {
                        Text(account.isAsset ? "$" : "−$")
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                        CurrencyField(
                            value: $newBalance,
                            prompt: "0",
                            accent: account.isAsset ? Theme.sage : Theme.terracotta
                        )
                    }
                } header: {
                    Text(account.isAsset ? "Current balance" : "Currently owed")
                } footer: {
                    Text("Last updated \(relativeDate)")
                        .font(Typography.Support.caption)
                }

                Section("Note (optional)") {
                    TextField("e.g. paid down balance, deposit cleared", text: $note)
                }
            }
            .navigationTitle("Update Balance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!hasChanged)
                }
            }
            .onAppear { amountFocused = true }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Actions

    private func save() {
        let snapshot = account.recordNewBalance(
            newBalance,
            note: note.trimmingCharacters(in: .whitespaces).isEmpty ? nil : note
        )
        modelContext.insert(snapshot)
        try? modelContext.save()
        dismiss()
    }

    // MARK: - Helpers

    private var relativeDate: String {
        let days = account.daysSinceBalanceUpdate
        if days == 0 { return "today" }
        if days == 1 { return "yesterday" }
        return "\(days) days ago"
    }
}
