import Foundation
import MoMoCore

/// The v2 invoice contract. Monetary values and validity seconds are strings on the wire.
public struct InvoiceRequest: Codable, Sendable, Equatable {
    public let externalId: String
    public let amount: String
    public let currency: String
    public let validityDuration: String
    public let intendedPayer: Party
    public let payee: Party
    public let description: String?

    public init(externalId: String, amount: String, currency: String, validityDuration: String, intendedPayer: Party, payee: Party, description: String? = nil) {
        self.externalId = externalId
        self.amount = amount
        self.currency = currency
        self.validityDuration = validityDuration
        self.intendedPayer = intendedPayer
        self.payee = payee
        self.description = description
    }
}

/// Invoice lifecycle includes CREATED before payment processing begins.
public struct InvoiceState: RawRepresentable, Codable, Sendable, Equatable, Hashable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public var isTerminal: Bool { self == .successful || self == .failed }
    public static let created = Self(rawValue: "CREATED")
    public static let pending = Self(rawValue: "PENDING")
    public static let successful = Self(rawValue: "SUCCESSFUL")
    public static let failed = Self(rawValue: "FAILED")
    public init(from decoder: any Decoder) throws { rawValue = try decoder.singleValueContainer().decode(String.self) }
    public func encode(to encoder: any Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}

public struct InvoiceStatus: Codable, Sendable, Equatable {
    public let referenceId: String?
    public let externalId: String?
    public let amount: String?
    public let currency: String?
    public let intendedPayer: Party?
    public let description: String?
    public let status: InvoiceState
    public let paymentReference: String?
    public let invoiceId: String?
    public let expiryDateTime: String?
    public let payeeFirstName: String?
    public let payeeLastName: String?
    public let errorReason: RequestToPayStatus.Reason?
    @available(*, deprecated, renamed: "errorReason")
    public var reason: RequestToPayStatus.Reason? { errorReason }
}

public struct InvoiceCancellationRequest: Codable, Sendable, Equatable {
    public let externalId: String
    public init(externalId: String) { self.externalId = externalId }
}
