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
    
    
    /// Initiates a transfer and returns the generated reference ID.
    public func transfer(payload: TransferRequest, referenceId: UUID = UUID(), callbackURL: String? = nil) async throws -> String {
        let token = try await tokenProvider.getValidToken()
        let uuidString = referenceId.uuidString
        let endpoint = TransferEndpoint.initiate(referenceId: uuidString, payload: payload, callbackURL: callbackURL)
        
        // POST returns 202 Accepted without a body
        try await client.execute(endpoint, bearerToken: token)
        return uuidString
    }
    
    /// Fetches the current status of a specific transfer
    public func getTransferStatus(referenceId: String) async throws -> TransferStatus {
        let token = try await tokenProvider.getValidToken()
        let endpoint = TransferEndpoint.status(referenceId: referenceId)
        return try await client.execute(endpoint, responseType: TransferStatus.self, bearerToken: token)
    }
    
    /// Initiates a transfer and automatically polls until it reaches a final state
    public func transferAndWait(payload: TransferRequest, maxAttempts: Int = 12, delayBetweenAttempts: Duration = .seconds(5)) async throws -> TransferStatus {
        let referenceId = try await transfer(payload: payload)
        var attempts = 0
        
        while attempts < maxAttempts {
            attempts += 1
            try await Task.sleep(for: delayBetweenAttempts)
            let status = try await getTransferStatus(referenceId: referenceId)
            
            if status.status != .pending {
                return status
            }
        }
        throw MoMoError.unexpectedResponse
    }
    
}
