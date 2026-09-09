//
//  RequestToPayRequest.swift
//  MoMoSDK
//
//  Created by kobby on 06/09/2026.
//


import Foundation
import MoMoCore // Imports the shared Party model

public struct RequestToPayRequest: Codable, Sendable, Equatable {
    
    /// The amount to be requested from the payer. Must be formatted as a string (e.g., "15.00").
    public let amount: String
    
    /// The ISO 4217 currency code (e.g., "EUR", "GHS", "UGX").
    public let currency: String
    
    /// Your internal system's reference ID for this transaction (optional, but highly recommended).
    public let externalId: String
    
    /// The customer you are requesting money from.
    public let payer: Party
    
    /// The message that will be shown to the payer on their device (e.g., USSD prompt).
    public let payerMessage: String
    
    /// A note intended for the payee (the merchant/provider) for reconciliation.
    public let payeeNote: String
    
    public init(
        amount: String,
        currency: String,
        externalId: String,
        payer: Party,
        payerMessage: String,
        payeeNote: String
    ) {
        self.amount = amount
        self.currency = currency
        self.externalId = externalId
        self.payer = payer
        self.payerMessage = payerMessage
        self.payeeNote = payeeNote
    }
}

public struct RequestToPayStatus: Codable, Sendable, Equatable {
    
    /// The UUID reference ID that was generated during the initial POST request.
    public let financialTransactionId: String?
    
    /// The merchant's external ID provided in the initial request.
    public let externalId: String?
    
    /// The transaction amount.
    public let amount: String
    
    /// The ISO 4217 currency code.
    public let currency: String
    
    /// The customer who was requested to pay.
    public let payer: Party
    
    /// The message that was shown to the payer.
    public let payerMessage: String?
    
    /// The note intended for the payee.
    public let payeeNote: String?
    
    /// The current state of the transaction (PENDING, SUCCESSFUL, FAILED).
    public let status: TransactionStatus
    
    /// If the status is FAILED, this provides the specific MoMo error code (e.g., "NOT_ENOUGH_FUNDS").
    public let reason: Reason?
    
    public struct Reason: Codable, Sendable, Equatable {
        public let code: String
        public let message: String
    }
}
