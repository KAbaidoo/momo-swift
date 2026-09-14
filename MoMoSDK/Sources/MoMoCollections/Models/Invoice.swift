//
//  Invoice.swift
//  MoMoSDK
//
//  Created by kobby on 14/09/2026.
//

import Foundation
import MoMoCore


/// Payload to create new invoice for a customer.
public struct InvoiceRequest: Codable, Sendable, Equatable {
    public let externalId: String
    public let amount: String
    public let currency: String
    public let validity: Int
    public let intendedPayer: Party
    public let payeeNote: String
    public let description: String
    
    public init(externalId: String, amount: String, currency: String, validity: Int, intendedPayer: Party, payeeNote: String, description: String) {
        self.externalId = externalId
        self.amount = amount
        self.currency = currency
        self.validity = validity
        self.intendedPayer = intendedPayer
        self.payeeNote = payeeNote
        self.description = description
    }
}

/// The response payload when querying an invoice's status
public struct InvoiceStatus: Codable, Sendable, Equatable {
    public let externalId: String?
    public let amount: String
    public let currency: String
    public let intendedPayer: Party
    public let payeeNote: String?
    public let description: String?
    public let status: TransactionStatus
    public let reason: RequestToPayStatus.Reason?
    
}
