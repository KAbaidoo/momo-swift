//
//  Deposit.swift
//  MoMoSDK
//
//  Created by kobby on 25/09/2026.
//

import Foundation
import MoMoCore

public struct DepositRequest: Codable, Sendable, Equatable {
    public let amount: String
    public let currency: String
    public let externalId: String
    public let payee: Party
    public let payerMessage: String
    public let payeeNote: String
    
    public init(amount: String, currency: String, externalId: String, payee: Party, payerMessage: String, payeeNote: String) {
        self.amount = amount
        self.currency = currency
        self.externalId = externalId
        self.payee = payee
        self.payerMessage = payerMessage
        self.payeeNote = payeeNote
    }
}


public struct DepositStatus: Codable, Sendable, Equatable {
    public let financialTransactionId: String?
    public let externalId: String?
    public let amount: String
    public let currency: String
    public let payee: Party
    public let status: TransactionStatus
    public let reason: TransferStatus.Reason?
    
}
