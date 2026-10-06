import Foundation
import MoMoCore

enum CollectionValidation {
    static func currency(_ value: String) throws {
        guard value.range(of: "^[A-Z]{3}$", options: .regularExpression) != nil else {
            throw MoMoError.invalidConfiguration("Currency must be a three-letter uppercase code")
        }
    }
    static func money(_ amount: String, _ code: String) throws {
        try MoMoValidation.amount(amount)
        try currency(code)
    }
    static func party(_ value: Party) throws {
        guard !value.partyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MoMoError.invalidConfiguration("Party identifier is empty")
        }
    }
}
