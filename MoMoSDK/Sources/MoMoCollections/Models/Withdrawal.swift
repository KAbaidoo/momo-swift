//
//  Withdrawal.swift
//  MoMoSDK
//
//  Created by kobby on 09/09/2026.
//

import Foundation
import MoMoCore

public struct RequestToWithdrawRequest: Codable, Sendable, Equatable {
    public let amount: String
    public let currency: String
    public let externalId: String
    public let payer: Party
    public let payerMessage: String
    public let payeeNote: String
    
    public init(amount: String, currency: String, externalId: String, payer: Party, payerMessage: String, payeeNote: String) {
        self.amount = amount
        self.currency = currency
        self.externalId = externalId
        self.payer = payer
        self.payerMessage = payerMessage
        self.payeeNote = payeeNote
    }
}


public struct RequestToWithdrawStatus: Codable, Sendable, Equatable {
    public let financialTransactionId: String?
    public let externalId: String?
    public let amount: String?
    public let currency: String?
    public let payer: Party?
    public let payerMessage: String?
    public let payeeNote: String?
    public let status: TransactionStatus
    public let reason: RequestToPayStatus.Reason?
    
}

/// V1 delivers POST callbacks; V2 delivers PUT callbacks. Status queries use v1 for both.
public enum WithdrawalVersion: String, Sendable { case v1 = "v1_0", v2 = "v2_0" }
