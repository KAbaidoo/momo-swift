//
//  MoMoDisbursementClient.swift
//  MoMoSDK
//
//  Created by kobby on 21/09/2026.
//


import Foundation
import MoMoCore

public struct MoMoDisbursementClient {
    internal let client: MoMoAPIClient
    internal let tokenProvider: MoMoTokenProvider
    
    /// Primary public initializer for app developers
    public init(credentials: MoMoCredentials, environment: MoMoEnvironment) {
        let client = MoMoAPIClient(
            environment: environment,
            subscriptionKey: credentials.subscriptionKey
        )
        let tokenProvider = MoMoTokenProvider(
            apiUser: credentials.apiUser,
            apiKey: credentials.apiKey,
            tokenPath: "/disbursement/token/",
            client: client
        )
        self.init(client: client, tokenProvider: tokenProvider)
    }
    
    /// Internal initializer for dependency injection and unit testing
    internal init(client: MoMoAPIClient, tokenProvider: MoMoTokenProvider) {
        self.client = client
        self.tokenProvider = tokenProvider
    }
    
    
}
