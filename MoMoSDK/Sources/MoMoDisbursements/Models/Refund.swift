//
//  Refund.swift
//  MoMoSDK
//
//  Created by kobby on 25/09/2026.
//

import Foundation
import MoMoCore

public struct RefundRequest: Codable, Sendable, Equatable {
    public let amount: String
    public let currency: String
    public let externalId: String
    public let payerMessage: String
    public let payeeNote: String
    public let referenceIdToRefund: String
    
    public init(amount: String, currency: String, externalId: String, payerMessage: String, payeeNote: String, referenceIdToRefund: String) {
        self.amount = amount
        self.currency = currency
        self.externalId = externalId
        self.payerMessage = payerMessage
        self.payeeNote = payeeNote
        self.referenceIdToRefund = referenceIdToRefund
    }
}

public struct RefundStatus: Codable, Sendable, Equatable {
    public let financialTransactionId: String?
    public let externalId: String?
    public let amount: String
    public let currency: String
    public let status: TransactionStatus
    public let reason: TransferStatus.Reason?
}
