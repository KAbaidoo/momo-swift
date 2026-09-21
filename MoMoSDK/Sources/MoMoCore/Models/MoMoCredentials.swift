//
//  MoMoCredentials.swift
//  MoMoSDK
//
//  Created by kobby on 21/09/2026.
//

import Foundation

public struct MoMoCredentials: Sendable, Hashable {
    public let apiUser: String
    public let apiKey: String
    public let subscriptionKey: String
    
    public init(apiUser: String, apiKey: String, subscriptionKey: String) {
        self.apiUser = apiUser
        self.apiKey = apiKey
        self.subscriptionKey = subscriptionKey
    }
}
