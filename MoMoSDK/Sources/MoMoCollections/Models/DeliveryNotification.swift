//
//  DeliveryNotification.swift
//  MoMoSDK
//
//  Created by kobby on 07/09/2026.
//

import Foundation

/// Payload for notifying the MoMo platform that a service/product was delivered.
public struct DeliveryNotification: Codable, Sendable, Equatable {
    public let notificationMessage: String
    
    public init(notificationMessage: String) {
        self.notificationMessage = notificationMessage
    }
}
