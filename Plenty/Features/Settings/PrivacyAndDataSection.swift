//
//  PrivacyAndDataSection.swift
//  Plenty
//
//  Target path: Plenty/Features/Settings/PrivacyAndDataSection.swift
//
//  Settings section that makes the privacy promise visible in-app and
//  gives the user the nuclear option: erase everything stored locally
//  and in iCloud.
//
//  PRD §13 non-goals: "Never sell or share data. No analytics, no
//  advertising, no data partnerships, no third-party SDKs." This
//  section restates the promise in plain language and provides:
//
//    • "What we collect" → opens a sheet with the plain-English
//      privacy summary (matches the App Store privacy nutrition label
//      and the website privacy page).
//    • "Erase all data" → a destructive button that wipes every
//      @Model record from the local store. CloudKit will remove the
//      records from the user's private database on next sync.
//

import SwiftUI
import SwiftData

struct PrivacyAndDataSection: View {

    @Environment(\.modelContext) private var modelContext

    @State private var showingSummary = false
    @State private var showingEraseConfirm = false

    var body: some View {
        Section {
            promiseRow

            Button {
                showingSummary = true
            } label: {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundStyle(.secondary)
                        .frame(width: 28)
                    Text("What we collect")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                showingEraseConfirm = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                        .frame(width: 28)
                    Text("Erase all data")
                    Spacer()
                }
                .contentShape(Rectangle())
            }
        } header: {
            Text("Privacy & Data")
        } footer: {
            Text("Plenty stores your data on this device and in your private iCloud. Erasing here removes both, immediately and permanently.")
        }
        .sheet(isPresented: $showingSummary) {
            PrivacySummarySheet()
        }
        .confirmationDialog(
            "Erase all Plenty data?",
            isPresented: $showingEraseConfirm,
            titleVisibility: .visible
        ) {
            Button("Erase everything", role: .destructive) {
                eraseAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes every account, transaction, bill, goal, and subscription Plenty has stored. iCloud copies will also be removed on next sync. This can't be undone.")
        }
    }

    // MARK: - Promise Row

    private var promiseRow: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield")
                .foregroundStyle(Theme.sage)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 28, alignment: .center)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text("On your device. Yours.")
                    .font(Typography.Body.emphasis)
                Text("No bank connections. No analytics. No third-party SDKs. Apple Intelligence runs on-device.")
                    .font(Typography.Support.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Actions

    private func eraseAll() {
        // Mirror DemoModeService.clearAll, but for the user's real data.
        let modelTypes: [any PersistentModel.Type] = [
            Transaction.self,
            AccountBalance.self,
            Account.self,
            IncomeSource.self,
            SavingsGoal.self,
            SpendingLimit.self,
            Subscription.self,
        ]
        for type in modelTypes {
            try? modelContext.delete(model: type)
        }
        try? modelContext.save()

        // Clear demo flag too in case the user erased while in demo mode.
        DemoModeService.isActive = false
    }
}

// MARK: - Privacy Summary Sheet

private struct PrivacySummarySheet: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    promise

                    section(
                        title: "What Plenty collects",
                        body: "Nothing. There is no analytics SDK. There is no telemetry. There is no crash reporter that ships data off your device."
                    )

                    section(
                        title: "Where your data lives",
                        body: "On this device, in the SwiftData store. If you have iCloud enabled, an encrypted copy syncs to your private iCloud database. Apple holds the keys for that copy in the same way they hold them for Notes and Reminders."
                    )

                    section(
                        title: "Who Plenty shares with",
                        body: "No one. There are no data partnerships, no advertisers, no aggregators. Apple Intelligence runs on your iPhone, not on a server."
                    )

                    section(
                        title: "What about Apple Intelligence",
                        body: "When Plenty asks the on-device model to write a sentence (\"You have $1,840 spendable\"), the request and response stay on the chip. Plenty doesn't use Private Cloud Compute for anything in V1."
                    )

                    section(
                        title: "Your right to leave",
                        body: "Tap Erase all data in Settings. Plenty deletes the local store immediately and queues a removal of every CloudKit record. Uninstalling the app removes the local copy. Removing it from Family Sharing or your Apple ID removes the iCloud copy."
                    )
                }
                .padding(20)
            }
            .navigationTitle("What we collect")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .background(Theme.background)
        }
    }

    private var promise: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Plenty's promise")
                .font(Typography.Title.small)
            Text("We collect: nothing. Your data goes: your device and your iCloud. We share with: no one.")
                .font(Typography.Body.regular)
                .foregroundStyle(.primary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.sage.opacity(Theme.Opacity.soft))
        )
    }

    private func section(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Typography.Body.emphasis)
                .foregroundStyle(.primary)
            Text(body)
                .font(Typography.Body.regular)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
