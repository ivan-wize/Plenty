//
//  BillDraft.swift
//  Plenty
//
//  Target path: Plenty/Intelligence/BillDraft.swift
//
//  Phase 5 (v2): the structured output of AIBillParser. Mirrors
//  ReceiptDraft's role for receipts but with bill-specific fields.
//
//  Returned by the document scanner pipeline when the captured text
//  classifies as a bill (utility statement, invoice, insurance
//  premium, etc.). BillEditorSheet accepts this as an init parameter
//  and pre-fills its fields.
//
//  Every field is optional — the parser returns nil for any field it
//  can't extract with confidence rather than guessing. The user fills
//  blanks manually in the editor.
//

import Foundation

struct BillDraft: Sendable, Equatable {
    var vendor: String?
    var amount: Decimal?
    /// Day of the month the bill is due (1-31).
    var dueDay: Int?
    var recurrence: Recurrence?
    var category: TransactionCategory?

    enum Recurrence: String, Sendable, Equatable, CaseIterable {
        case monthly
        case quarterly
        case annually

        var displayName: String {
            switch self {
            case .monthly:   return "Monthly"
            case .quarterly: return "Quarterly"
            case .annually:  return "Annually"
            }
        }
    }
}
