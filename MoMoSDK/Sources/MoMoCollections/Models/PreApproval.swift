import Foundation
import MoMoCore

public struct PreApprovalRequest: Codable, Sendable, Equatable {
    public let payer: Party
    public let payerCurrency: String
    public let payerMessage: String
    /// Duration in seconds for which the approved mandate is valid.
    public let validityTime: Int
    public init(payer: Party, payerCurrency: String, payerMessage: String, validityTime: Int) {
        self.payer = payer
        self.payerCurrency = payerCurrency
        self.payerMessage = payerMessage
        self.validityTime = validityTime
    }
}

/// MTN's schema declares an integer, while its description specifies an ISO timestamp.
/// Preserve either representation without guessing time units or a timezone.
public enum PreApprovalExpiration: Codable, Sendable, Equatable {
    case text(String)
    case integer(Int64)
    public init(from decoder: any Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let value = try? c.decode(String.self) { self = .text(value) }
        else { self = .integer(try c.decode(Int64.self)) }
    }
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self { case .text(let v): try c.encode(v); case .integer(let v): try c.encode(v) }
    }
}

public struct PreApprovalStatus: Codable, Sendable, Equatable {
    public let payer: Party?
    public let payerCurrency: String?
    public let payerMessage: String?
    public let status: TransactionStatus
    public let expirationDateTime: PreApprovalExpiration?
    public let reason: RequestToPayStatus.Reason?
    @available(*, deprecated, renamed: "status")
    public var transactionStatus: TransactionStatus { status }
}

public struct ApprovedPreApprovalState: RawRepresentable, Codable, Sendable, Equatable, Hashable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let approved = Self(rawValue: "APPROVED")
    public static let cancelled = Self(rawValue: "CANCELLED")
    public static let expired = Self(rawValue: "EXPIRED")
    public static let rejected = Self(rawValue: "REJECTED")
    public static let pending = Self(rawValue: "PENDING")
    public init(from decoder: any Decoder) throws { rawValue = try decoder.singleValueContainer().decode(String.self) }
    public func encode(to encoder: any Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}

/// An approved mandate, distinct from the status of the request that created it.
public struct ApprovedPreApproval: Codable, Sendable, Equatable {
    public let preApprovalId: String
    public let toFri: String
    public let fromFri: String
    public let fromCurrency: String
    public let createdTime: String
    public let status: ApprovedPreApprovalState
    public let message: String
    public let approvedTime: String?
    public let expiryTime: String?
    public let frequency: String?
    public let startDate: String?
    public let lastUsedDate: String?
    public let offer: String?
    public let externalId: String?
    public let maxDebitAmount: String?
}
