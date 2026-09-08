//
//  PreApprovalRequest.swift
//  MoMoSDK
//
//  Created by kobby on 08/09/2026.
//

import Foundation
import MoMoCore

public struct PreApprovalRequest: Codable, Sendable, Equatable {
    public let payer: Party
    public let payerCurrency: String
    public let payerMessage: String
    public let externalId: String
    
    public init(payer: Party, payerCurrency: String, payerMessage: String, externalId: String) {
        self.payer = payer
        self.payerCurrency = payerCurrency
        self.payerMessage = payerMessage
        self.externalId = externalId
    }
}

