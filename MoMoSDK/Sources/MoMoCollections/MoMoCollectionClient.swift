//
//  MoMoCollectionsClient.swift
//  MoMoSDK
//
//  Created by kobby on 06/09/2026.
//

import Foundation
import MoMoCore

public struct MoMoCollectionClient {
    private let client: MoMoAPIClient
    private let tokenProvider: MoMoTokenProvider
    
    public init(client: MoMoAPIClient, tokenProvider: MoMoTokenProvider) {
        self.client = client
        self.tokenProvider = tokenProvider
    }
    
    /// Initiates a RequestToPay transaction and returns the generated Reference ID.
    public func requestToPay(
        payload: RequestToPayRequest,
        referenceId: UUID = UUID(),
        callbackURL: String? = nil
    ) async throws -> String {
        let token = try await tokenProvider.getValidToken()
        let uuidString = referenceId.uuidString
        
        let endpoint = RequestToPayEndpoint.initiate(
            referenceId: uuidString,
            payload: payload,
            callbackURL: callbackURL
        )
        
        // POST /requesttopay returns 202 Accepted with no body on success
        try await client.execute(endpoint, bearerToken: token)
        
        return uuidString
    }
    
    /// Fetches the current status of a specific transaction.
    public func getTransactionStatus(referenceId: String) async throws -> RequestToPayStatus {
        let token = try await tokenProvider.getValidToken()
        let endpoint = RequestToPayEndpoint.status(referenceId: referenceId)
        
        return try await client.execute(endpoint, responseType: RequestToPayStatus.self, bearerToken: token)
    }
}

extension MoMoCollectionClient {
    
    /// Initiates a RequestToPay and continuously polls the status until it succeeds, fails, or times out.
    public func requestToPayAndWait(
        payload: RequestToPayRequest,
        maxAttempts: Int = 12,
        delayBetweenAttempts: Duration = .seconds(5)
    ) async throws -> RequestToPayStatus {
        
        let referenceId = try await requestToPay(payload: payload)
        var attempts = 0
        
        while attempts < maxAttempts {
            attempts += 1
            
            // Wait for the specified delay before checking (or between checks)
            try await Task.sleep(for: delayBetweenAttempts)
            
            let status = try await getTransactionStatus(referenceId: referenceId)
            
            switch status.status {
            case .success, .failed:
                // Final state reached
                return status
            case .pending:
                // Continue polling
                continue
            }
        }
        
        throw MoMoError.unexpectedResponse // Or a custom .timeout error
    }
}
