//
//  TransactionStatus.swift
//  MoMoSDK
//
//  Created by kobby on 06/09/2026.
//

import Foundation

public enum TransactionStatus: String, Codable, Sendable {
    case pending = "PENDING"
    case success = "SUCCESS"
    case failed = "FAILED"
}
