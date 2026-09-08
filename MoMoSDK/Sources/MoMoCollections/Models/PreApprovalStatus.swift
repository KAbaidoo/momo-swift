//
//  PreApprovalStatus.swift
//  MoMoSDK
//
//  Created by kobby on 08/09/2026.
//

import Foundation
import MoMoCore

public struct PreApprovalStatus: Codable, Sendable, Equatable {
    public let payer: Party
    public let payerCurrency: String
    public let payerMessage: String?
    public let externalId: String?
    public let transactionStatus: TransactionStatus
    
    public let preApprovalId: String?
}
