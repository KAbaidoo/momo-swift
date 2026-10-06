import Foundation
import MoMoCore

/// Identity types accepted by basic-user-info and approved-preapproval endpoints.
/// Their casing deliberately differs from the Party JSON representation.
public struct CollectionAccountIdentity: Sendable, Equatable {
    public enum Kind: String, Sendable { case msisdn = "MSISDN", email = "Email", alias = "Alias", id = "ID" }
    public let kind: Kind
    public let value: String
    public init(kind: Kind, value: String) { self.kind = kind; self.value = value }
    internal init(party: Party) throws {
        switch party.partyIdType.rawValue {
        case "MSISDN": self.init(kind: .msisdn, value: party.partyId)
        case "EMAIL": self.init(kind: .email, value: party.partyId)
        default: throw CollectionValidationError.unsupportedPartyType
        }
    }
}

public enum CollectionValidationError: Error, Sendable, Equatable {
    case unsupportedPartyType
    case invalidNotificationMessage
    case invalidLanguage
    case invalidValidity
}
