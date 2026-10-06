import Foundation
import MoMoCore
public struct RefundRequest: Codable, Sendable, Equatable {
    public let amount: String
    public let currency: String
    public let externalId: String?
    public let payerMessage: String?
    public let payeeNote: String?
    public let referenceIdToRefund: String
    public init(amount: String, currency: String, externalId: String? = nil, payerMessage: String? = nil, payeeNote: String? = nil, referenceIdToRefund: String) {
        self.amount = amount; self.currency = currency; self.externalId = externalId
        self.payerMessage = payerMessage; self.payeeNote = payeeNote; self.referenceIdToRefund = referenceIdToRefund
    }
}
public typealias RefundStatus = TransferStatus
