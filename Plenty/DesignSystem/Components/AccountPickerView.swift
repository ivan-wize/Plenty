//
//  AccountPickerView.swift
//  Plenty
//
//  Target path: Plenty/DesignSystem/AccountPickerView.swift
//
//  Modal picker for Account selection. Optionally filters to spendable
//  accounts (cash + credit) for expense/bill flows.
//

import SwiftUI

struct AccountPickerView: View {

    @Binding var selection: Account?
    let accounts: [Account]
    let spendableOnly: Bool

    @Environment(\.dismiss) private var dismiss

    private var availableAccounts: [Account] {
        let filtered = spendableOnly
            ? AccountDerivations.spendableAccounts(accounts)
            : AccountDerivations.activeAccounts(accounts)
        return filtered.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        NavigationStack {
            Group {
                if availableAccounts.isEmpty {
                    ContentUnavailableView {
                        Label("No accounts yet", systemImage: "creditcard")
                    } description: {
                        Text("Add an account from the Accounts tab to assign transactions to it.")
                    }
                } else {
                    List {
                        ForEach(availableAccounts) { account in
                            row(for: account)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(for account: Account) -> some View {
        Button {
            selection = account
            dismiss()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: account.category.iconName)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.sage)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle().fill(Theme.sage.opacity(Theme.Opacity.soft))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(account.name)
                        .font(Typography.Body.regular)
                        .foregroundStyle(.primary)

                    Text(account.category.displayName)
                        .font(Typography.Support.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if selection?.id == account.id {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.sage)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
