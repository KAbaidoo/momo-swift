import Foundation
import MoMoCore

public struct CollectionMoney: Codable, Sendable, Equatable {
    public let amount: String
    public let currency: String
    public init(amount: String, currency: String) { self.amount = amount; self.currency = currency }
}

/// The documented v2 payment payload, distinct from request-to-pay.
public struct PaymentRequest: Codable, Sendable, Equatable {
    public let externalTransactionId: String
    public let money: CollectionMoney
    public let customerReference: String
    public let serviceProviderUserName: String
    public let couponId: String?
    public let productId: String?
    public let productOfferingId: String?
    public let receiverMessage: String?
    public let senderNote: String?
    public let maxNumberOfRetries: Int?
    public let transferType: String?
    public let includeSenderCharges: Bool?
    public init(externalTransactionId: String, money: CollectionMoney, customerReference: String, serviceProviderUserName: String, couponId: String? = nil, productId: String? = nil, productOfferingId: String? = nil, receiverMessage: String? = nil, senderNote: String? = nil, maxNumberOfRetries: Int? = nil, includeSenderCharges: Bool? = nil, transferType: String? = nil) {
        self.externalTransactionId = externalTransactionId; self.money = money; self.customerReference = customerReference; self.serviceProviderUserName = serviceProviderUserName
        self.couponId = couponId; self.productId = productId; self.productOfferingId = productOfferingId; self.receiverMessage = receiverMessage; self.senderNote = senderNote; self.maxNumberOfRetries = maxNumberOfRetries; self.includeSenderCharges = includeSenderCharges; self.transferType = transferType
    }
}

public struct PaymentStatus: Codable, Sendable, Equatable {
    public let referenceId: String?
    public let status: InvoiceState
    public let financialTransactionId: String?
    public let reason: RequestToPayStatus.Reason?
}
