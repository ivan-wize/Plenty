//
//  ModelContext+SafeSave.swift
//  Plenty
//
//  Target path: Plenty/Utilities/ModelContext+SafeSave.swift
//
//  Ported from Left v1.0. Only change: the Logger subsystem identifier
//  now reads `com.plenty.app`.
//
//  Call this instead of `try? save()` so failures are never silent.
//

import SwiftData
import Foundation
import os

private let logger = Logger(subsystem: "com.plenty.app", category: "persistence")

extension ModelContext {

    /// Save with proper error logging.
    ///
    /// Returns `true` on success, `false` on failure. Logs the error so
    /// crashes and data-loss incidents can be traced without a debugger.
    @MainActor
    @discardableResult
    func safeSave() -> Bool {
        do {
            try save()
            return true
        } catch {
            logger.error("ModelContext save failed: \(error.localizedDescription)")
            return false
        }
    }
}
