//
//  TransferRequest.swift
//  MoMoSDK
//
//  Created by kobby on 24/09/2026.
//

import Foundation
import MoMoCore

/// The payload to initiate a transfer (payout) to a customer's MoMo wallet.
public struct TransferRequest: Codable, Sendable, Equatable {
    public let amount: String
    public let currency: String
    public let externalId: String
    public let payee: Party
    public let payerMessage: String
    public let payerNote: String
    
    public init(amount: String, currency: String, externalId: String, payee: Party, payerMessage: String, payerNote: String) {
        self.amount = amount
        self.currency = currency
        self.externalId = externalId
        self.payee = payee
        self.payerMessage = payerMessage
        self.payerNote = payerNote
    }
}

/// The response payload when querying a transfer's status
public struct TransferStatus: Codable, Sendable, Equatable {
    public let financialTransactionId: String?
    public let externalId: String?
    public let amount: String
    public let currency: String
    public let payer: Party
    public let status: TransactionStatus
    public let reason: Reason?
    
    public struct Reason: Codable, Sendable, Equatable {
        public let code: String
        public let message: String
    }
    
}
