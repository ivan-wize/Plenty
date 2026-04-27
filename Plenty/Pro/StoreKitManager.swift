//
//  StoreKitManager.swift
//  Plenty
//
//  Target path: Plenty/Pro/StoreKitManager.swift
//
//  Single source of truth for Plenty Pro purchase state. Handles:
//
//    • Loading the product from the App Store
//    • Restoring previous purchases on launch
//    • Initiating a purchase
//    • Observing transactions (refunds, family sharing, parental approval)
//    • Updating AppState.isProUnlocked when state changes
//
//  iOS 26 StoreKit 2 only. No StoreKit 1 fallback.
//
//  Product ID: "com.plenty.app.pro" — one-time, non-consumable, $9.99.
//  Configure in App Store Connect and Plenty.storekit (test config).
//
//  IMPORTANT — namespace collision:
//  This module already defines `Transaction` as a SwiftData @Model
//  (Plenty/Models/Transaction.swift). The unqualified name `Transaction`
//  inside the Plenty module therefore resolves to the SwiftData class,
//  which has no `currentEntitlements` or `updates`. Always reference
//  StoreKit's transaction type via the `StoreTransaction` typealias
//  defined below.
//

import Foundation
import StoreKit
import os
import Observation

// Disambiguates StoreKit's Transaction from the project's SwiftData
// @Model named Transaction. Only this file uses StoreKit's, so the
// typealias is local-scoped intent.
typealias StoreTransaction = StoreKit.Transaction

private let logger = Logger(subsystem: "com.plenty.app", category: "storekit")

@Observable
@MainActor
final class StoreKitManager {

    // MARK: - Constants

    static let proProductID = "com.plenty.app.pro"

    // MARK: - State

    /// The Pro product, loaded from the App Store. Nil while loading or
    /// on failure. Views can read `formattedPrice` for display.
    private(set) var proProduct: Product?

    /// Whether the product load is in progress.
    private(set) var isLoadingProduct = false

    /// Whether a purchase is currently in flight.
    private(set) var isPurchasing = false

    /// Last error from a purchase or load attempt. Cleared on next success.
    private(set) var lastError: Error?

    /// Reference to AppState so this manager can flip isProUnlocked.
    /// Set by PlentyApp via `attach(appState:)` after both objects exist.
    private weak var appState: AppState?

    // MARK: - Init
    //
    // Note: we deliberately do NOT store the transaction-listener Task
    // on `self`. Storing it forces a `deinit` body that touches a
    // @MainActor-isolated property from a nonisolated context, which
    // Swift 6 strict concurrency rejects. Instead the listener captures
    // `self` weakly and exits on the next emission after deallocation.
    //
    // In practice StoreKitManager lives for the app lifetime (held as
    // @State on PlentyApp), so the listener never needs to be torn down.

    init(appState: AppState? = nil) {
        self.appState = appState
        startTransactionListener()
    }

    /// Set the AppState reference. Called once by PlentyApp after both
    /// objects exist (the cross-wiring happens in `.task` because
    /// @State property initializers can't reference one another).
    func attach(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Public Surface

    /// Display price ("$9.99"). Falls back to a placeholder while loading.
    var formattedPrice: String {
        proProduct?.displayPrice ?? "$9.99"
    }

    /// Load the Pro product from the App Store. Idempotent; safe to call
    /// repeatedly (results cached after first success).
    func loadProduct() async {
        guard proProduct == nil else { return }
        isLoadingProduct = true
        defer { isLoadingProduct = false }

        do {
            let products = try await Product.products(for: [Self.proProductID])
            self.proProduct = products.first
            if proProduct == nil {
                logger.warning("Pro product not found in App Store response.")
            }
        } catch {
            logger.error("Failed to load Pro product: \(error.localizedDescription)")
            self.lastError = error
        }
    }

    /// Check current entitlements at launch. Sets isProUnlocked if a
    /// valid Pro purchase exists.
    func refreshEntitlements() async {
        for await result in StoreTransaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.proProductID,
               transaction.revocationDate == nil {
                appState?.isProUnlocked = true
                return
            }
        }
        // No valid entitlement found.
        appState?.isProUnlocked = false
    }

    /// Initiate a purchase. Returns true on success.
    @discardableResult
    func purchasePro() async -> Bool {
        guard let product = proProduct else {
            logger.warning("purchasePro called before product loaded.")
            await loadProduct()
            guard proProduct != nil else { return false }
            return await purchasePro()
        }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    appState?.isProUnlocked = true
                    await transaction.finish()
                    return true
                } else {
                    logger.warning("Purchase verification failed.")
                    return false
                }
            case .userCancelled:
                return false
            case .pending:
                // Parental approval, payment-method action required, etc.
                // The listener will pick it up when it resolves.
                return false
            @unknown default:
                return false
            }
        } catch {
            logger.error("Purchase failed: \(error.localizedDescription)")
            self.lastError = error
            return false
        }
    }

    /// Restore previous purchases. Calls AppStore.sync() and re-checks
    /// entitlements. Used by the "Restore Purchases" button.
    @discardableResult
    func restorePurchases() async -> Bool {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            return appState?.isProUnlocked ?? false
        } catch {
            logger.error("Restore failed: \(error.localizedDescription)")
            self.lastError = error
            return false
        }
    }

    // MARK: - Transaction Listener

    /// Long-running task that listens for transaction updates from
    /// outside the app (refunds, family sharing changes, parental
    /// approval completion). Captures `self` weakly so it self-terminates
    /// on the next emission after deallocation.
    private func startTransactionListener() {
        Task.detached(priority: .background) { [weak self] in
            for await result in StoreTransaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = result,
                   transaction.productID == Self.proProductID {
                    let revoked = transaction.revocationDate != nil
                    await MainActor.run {
                        self.appState?.isProUnlocked = !revoked
                    }
                    await transaction.finish()
                }
            }
        }
    }
}
