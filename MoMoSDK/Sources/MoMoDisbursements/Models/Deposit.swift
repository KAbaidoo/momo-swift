import Foundation
import MoMoCore

public struct DepositRequest: Codable, Sendable, Equatable {
    public let amount: String
    public let currency: String
    public let externalId: String?
    public let payee: Party
    public let payerMessage: String?
    public let payeeNote: String?
    public init(amount: String, currency: String, externalId: String? = nil, payee: Party, payerMessage: String? = nil, payeeNote: String? = nil) {
        self.amount = amount; self.currency = currency; self.externalId = externalId
        self.payee = payee; self.payerMessage = payerMessage; self.payeeNote = payeeNote
    }
}

public typealias DepositStatus = TransferStatus
