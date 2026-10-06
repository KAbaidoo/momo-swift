import Foundation
import MoMoCore

/// Transfer amounts remain decimal strings to preserve exact money values.
public struct TransferRequest: Codable, Sendable, Equatable {
    public let amount: String
    public let currency: String
    public let externalId: String?
    public let payee: Party
    public let payerMessage: String?
    public let payeeNote: String?
    /// Aggregator routing value agreed with MTN; omitted for ordinary transfers.
    public let transferType: String?
    public init(amount: String, currency: String, externalId: String? = nil, payee: Party, payerMessage: String? = nil, payeeNote: String? = nil, transferType: String? = nil) {
        self.amount = amount; self.currency = currency; self.externalId = externalId
        self.payee = payee; self.payerMessage = payerMessage; self.payeeNote = payeeNote; self.transferType = transferType
    }
    @available(*, deprecated, renamed: "payeeNote")
    public var payerNote: String? { payeeNote }
    @available(*, deprecated, message: "Use payeeNote; the API wire field is payeeNote.")
    public init(amount: String, currency: String, externalId: String, payee: Party, payerMessage: String, payerNote: String) {
        self.init(amount: amount, currency: currency, externalId: externalId, payee: payee, payerMessage: payerMessage, payeeNote: payerNote)
    }
}

/// Published responses permit omitted transaction metadata.
public struct TransferStatus: Codable, Sendable, Equatable {
    public let financialTransactionId: String?
    public let externalId: String?
    public let amount: String?
    public let currency: String?
    public let payee: Party?
    public let payerMessage: String?
    public let payeeNote: String?
    public let status: TransactionStatus?
    public let reason: Reason?
    @available(*, deprecated, renamed: "payee")
    public var payer: Party? { payee }
    public struct Reason: Codable, Sendable, Equatable {
        public let code: String?
        public let message: String?
        public init(code: String? = nil, message: String? = nil) { self.code = code; self.message = message }
    }
}

/// v1 callbacks use POST; v2 callbacks use PUT. Both status lookups use v1.
public enum DisbursementAPIVersion: String, Codable, Sendable { case v1 = "v1_0", v2 = "v2_0" }
