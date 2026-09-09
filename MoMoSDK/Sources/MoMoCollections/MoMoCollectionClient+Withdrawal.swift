//
//  MoMoCollectionClient+Withdrawal.swift
//  MoMoSDK
//
//  Created by kobby on 09/09/2026.
//

import Foundation
import MoMoCore

extension MoMoCollectionClient {
    /// Initiates a Request to Withdraw transaction.
    public func requestToWithdraw(payload: RequestToWithdrawRequest, referenceId: UUID = UUID(), callbackURL: String? = nil) async throws -> String {
        let token = try await tokenProvider.getValidToken()
        let uuidString = referenceId.uuidString
        let endpoint = WithdrawalEndpoint.initiate(referenceId: uuidString, payload: payload, callbackURL: callbackURL)
        
        try await client.execute(endpoint, bearerToken: token)
        return uuidString
    }
    
    /// Fetches the status of a Request to Withdraw transaction.
    public func getWithdrawalStatus(referenceId: String) async throws -> RequestToWithdrawStatus {
        let token = try await tokenProvider.getValidToken()
        let endpoint = WithdrawalEndpoint.status(referenceId: referenceId)
        
        return try await client.execute(endpoint, responseType: RequestToWithdrawStatus.self, bearerToken: token)
    }
    
    /// Initiates a Withdrawal and then polls until the transaction reaches a final state
    public func requestToWithdrawAndWait(payload: RequestToWithdrawRequest, maxAttempts: Int = 12, delayBetweenAttempts: Duration = .seconds(5)) async throws -> RequestToWithdrawStatus {
        let referenceId = try await requestToWithdraw(payload: payload)
        var attempts = 0
        
        while attempts < maxAttempts {
            attempts += 1
            try await Task.sleep(for: delayBetweenAttempts)
            
            let status = try await getWithdrawalStatus(referenceId: referenceId)
            if status.status != .pending {
                return status
            }
        }
        throw MoMoError.unexpectedResponse
    }
}
