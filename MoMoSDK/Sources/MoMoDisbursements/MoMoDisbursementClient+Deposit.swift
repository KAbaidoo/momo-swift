//
//  MoMoDisbursementClient+Deposit.swift
//  MoMoSDK
//
//  Created by kobby on 25/09/2026.
//

import Foundation
import MoMoCore

extension MoMoDisbursementClient {
    
    /// Initiates a Deposit to a MoMo Wallet and returns the reference ID.
    public func deposit(payload: DepositRequest, referenceId: UUID = UUID(), callbackURL: String? = nil) async throws -> String {
        let token = try await tokenProvider.getValidToken()
        let uuidString = referenceId.uuidString
        let endpoint = DepositEndpoint.initiate(referenceId: uuidString, payload: payload, callbackURL: callbackURL)
        
        try await client.execute(endpoint, bearerToken: token)
        
        return uuidString
    }
    
    /// Fetches the status of a Deposit transaction.
    public func getDepositStatus(referenceId: String) async throws -> DepositStatus {
        let token = try await tokenProvider.getValidToken()
        let endpoint = DepositEndpoint.status(referenceId: referenceId)
        
        return try await client.execute(endpoint, responseType: DepositStatus.self, bearerToken: token)
    }
    
    /// Initiates a Deposit and polls until a final state is reached.
        public func depositAndWait(
            payload: DepositRequest,
            maxAttempts: Int = 12,
            delayBetweenAttempts: Duration = .seconds(5)
        ) async throws -> DepositStatus {
            let referenceId = try await deposit(payload: payload)
            var attempts = 0
            
            while attempts < maxAttempts {
                attempts += 1
                try await Task.sleep(for: delayBetweenAttempts)
                
                let status = try await getDepositStatus(referenceId: referenceId)
                if status.status != .pending { return status }
            }
            
            throw MoMoError.unexpectedResponse
        }
}
