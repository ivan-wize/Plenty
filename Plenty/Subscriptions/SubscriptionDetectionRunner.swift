//
//  SubscriptionDetectionRunner.swift
//  Plenty
//
//  Target path: Plenty/Subscriptions/SubscriptionDetectionRunner.swift
//
//  Orchestrates SubscriptionDetector. Reads transactions and existing
//  subscriptions, runs detection, persists any new candidates as
//  Subscription records with state=.suggested.
//
//  Idempotent — pattern uniqueness is enforced via Subscription's
//  rawMerchantPattern, so re-running doesn't duplicate. Cheap to run
//  on app open.
//

import Foundation
import SwiftData
import os

private let logger = Logger(subsystem: "com.plenty.app", category: "subscriptions")

@MainActor
struct SubscriptionDetectionRunner {

    let modelContext: ModelContext

    /// Run detection. Inserts new suggested Subscription records for
    /// patterns not already represented. Returns count of new
    /// suggestions created.
    @discardableResult
    func run() async -> Int {
        do {
            let transactions = try modelContext.fetch(FetchDescriptor<Transaction>())
            let subscriptions = try modelContext.fetch(FetchDescriptor<Subscription>())

            let detected = SubscriptionDetector.detect(
                in: transactions,
                existing: subscriptions
            )

            var newCount = 0
            for candidate in detected {
                let next = projectedNextCharge(
                    cadence: candidate.cadence,
                    lastCharge: candidate.lastChargeDate
                )

                let subscription = Subscription(
                    merchantName: candidate.merchantName,
                    rawMerchantPattern: candidate.normalizedPattern,
                    typicalAmount: candidate.typicalAmount,
                    cadence: candidate.cadence,
                    nextChargeDate: next,
                    lastChargeDate: candidate.lastChargeDate,
                    state: .suggested
                )
                modelContext.insert(subscription)
                newCount += 1
            }

            if newCount > 0 {
                try modelContext.save()
                logger.info("Subscription detection: created \(newCount) new suggestions.")
            }

            return newCount
        } catch {
            logger.error("Subscription detection failed: \(error.localizedDescription)")
            return 0
        }
    }

    // MARK: - Projection

    private func projectedNextCharge(cadence: Subscription.Cadence, lastCharge: Date) -> Date? {
        let cal = Calendar.current
        let component: Calendar.Component
        let value: Int
        switch cadence {
        case .weekly:  component = .day;   value = 7
        case .monthly: component = .month; value = 1
        case .annual:  component = .year;  value = 1
        }
        return cal.date(byAdding: component, value: value, to: lastCharge)
    }
}
