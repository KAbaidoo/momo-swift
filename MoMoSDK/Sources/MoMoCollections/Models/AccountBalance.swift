//
//  AccountBalance.swift
//  MoMoSDK
//
//  Created by kobby on 07/09/2026.
//

import Foundation


/// Represents the available balance in a merchant's Collection wallet.
public struct AccountBalance: Codable, Sendable, Equatable {
    public let availableBalance: String
    public let currency: String
}
