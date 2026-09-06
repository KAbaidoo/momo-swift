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