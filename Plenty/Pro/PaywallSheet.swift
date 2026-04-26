//
//  PaywallSheet.swift
//  Plenty
//
//  Target path: Plenty/Pro/PaywallSheet.swift
//
//  The Pro purchase sheet. Calm and restrained — Plenty's voice
//  doesn't do high-pressure sales. Three value props, one price, one
//  button. Restore Purchases lives in the toolbar.
//
//  Presented from PlanLockedView when the user taps Unlock.
//

import SwiftUI
import StoreKit

struct PaywallSheet: View {

    @Environment(StoreKitManager.self) private var storeKit
    @Environment(\.dismiss) private var dismiss

    @State private var isPurchasing = false
    @State private var purchaseError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    heroSection
                    valueProps
                    purchaseSection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
            .background(Theme.background)
            .navigationTitle("Plenty Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            Task { await restore() }
                        } label: {
                            Label("Restore Purchases", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("Purchase Failed", isPresented: errorBinding) {
                Button("OK", role: .cancel) { purchaseError = nil }
            } message: {
                Text(purchaseError ?? "")
            }
        }
        .task { await storeKit.loadProduct() }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Theme.sage)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 120, height: 120)
                .background(
                    Circle().fill(Theme.sage.opacity(Theme.Opacity.soft))
                )

            VStack(spacing: 8) {
                Text("See past today")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text("Unlock the Plan tab to look ahead, save toward what matters, and watch your trends.")
                    .font(Typography.Body.regular)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
        }
    }

    // MARK: - Value Props

    private var valueProps: some View {
        VStack(spacing: 18) {
            valueProp(
                icon: "calendar",
                title: "Outlook",
                description: "Twelve months projected from your real data, so you can see when you'll be flush and when you'll be tight."
            )
            valueProp(
                icon: "leaf",
                title: "Save",
                description: "Set savings goals and pay down debt with avalanche or snowball strategies. Plenty does the math."
            )
            valueProp(
                icon: "chart.bar",
                title: "Trends",
                description: "Six months of net worth and a clear breakdown of where your money goes by category."
            )
        }
    }

    private func valueProp(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title3.weight(.medium))
                .foregroundStyle(Theme.sage)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Typography.Body.emphasis)
                    .foregroundStyle(.primary)
                Text(description)
                    .font(Typography.Body.regular)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Purchase

    private var purchaseSection: some View {
        VStack(spacing: 12) {
            Button {
                Task { await purchase() }
            } label: {
                HStack {
                    Spacer()
                    if isPurchasing {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        Text("Unlock for \(storeKit.formattedPrice)")
                            .font(Typography.Body.emphasis)
                    }
                    Spacer()
                }
                .padding(.vertical, 16)
            }
            .background(Theme.sage)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .disabled(isPurchasing || storeKit.proProduct == nil)

            Text("One-time purchase. No subscriptions, ever.")
                .font(Typography.Support.footnote)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Actions

    private func purchase() async {
        isPurchasing = true
        defer { isPurchasing = false }

        let success = await storeKit.purchasePro()
        if success {
            dismiss()
        } else if let error = storeKit.lastError {
            purchaseError = error.localizedDescription
        }
    }

    private func restore() async {
        let restored = await storeKit.restorePurchases()
        if restored {
            dismiss()
        } else {
            purchaseError = "No previous purchases found on this Apple ID."
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { purchaseError != nil },
            set: { if !$0 { purchaseError = nil } }
        )
    }
}
