//
//  Voucher.swift
//  MoMoSDK
//
//  Created by kobby on 15/09/2026.
//

import Foundation
import MoMoCore

/// The payload to generate a new MoMo payment voucher.
public struct VoucherRequest: Codable, Sendable, Equatable {
    public let amount: String
    public let currency: String
    public let externalId: String
    public let payeeNote: String
    public let payerMessage: String
    
    public init(amount: String, currency: String, externalId: String, payeeNote: String, payerMessage: String) {
        self.amount = amount
        self.currency = currency
        self.externalId = externalId
        self.payeeNote = payeeNote
        self.payerMessage = payerMessage
    }
}

/// The response payload when querying a voucher's status.
public struct VoucherStatus: Codable, Sendable, Equatable {
    public let externalId: String?
    public let amount: String
    public let currency: String
    public let payeeNote: String?
    public let payerMessage: String?
    public let status: TransactionStatus
    public let reason: RequestToPayStatus.Reason?
    
    /// The OTP code generated for the voucher (availability depends on API permissions).
    public let voucherCode: String?
}

