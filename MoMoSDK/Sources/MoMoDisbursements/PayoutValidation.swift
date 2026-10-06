import Foundation
import MoMoCore

enum PayoutValidation {
    static func money(amount: String, currency: String) throws {
        try MoMoValidation.amount(amount)
        guard currency.range(of: "^[A-Z]{3}$", options: .regularExpression) != nil else {
            throw MoMoError.invalidConfiguration("Currency must be a three-letter uppercase code")
        }
    }
    static func party(_ party: Party) throws {
        guard !party.partyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw MoMoError.invalidConfiguration("Payee identifier is empty") }
    }
    static func reference(_ id: String) throws {
        try MoMoValidation.referenceId(id)
    }
    static func callback(_ callback: String?) throws {
        try MoMoValidation.callbackURL(callback)
    }
}
