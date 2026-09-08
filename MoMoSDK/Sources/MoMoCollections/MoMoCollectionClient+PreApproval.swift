//
//  MoMoCollectionClient+PreApproval.swift
//  MoMoSDK
//
//  Created by kobby on 07/09/2026.
//

import Foundation
import MoMoCore

extension MoMoCollectionClient {
    
    /// Initiates an auto-debit Pre-Approval mandate and returns the reference ID
    public func requestPreApproval(payload: PreApprovalRequest, referenceId: UUID = UUID(), callbackURL: String? = nil) async throws -> String {
        let token = try await tokenProvider.getValidToken()
        let uuidString = referenceId.uuidString
        let endpoint = PreApprovalEndpoint.initiate(referenceId: uuidString, payload: payload, callbackURL: callbackURL)
        
        try await client.execute(endpoint, bearerToken: token)
        return uuidString
        
    }
    
    /// Fetches the status of a specific Pre-Approval mandate.
    public func getPreApprovalStatus(referenceId: String) async throws -> PreApprovalStatus {
        let token = try await tokenProvider.getValidToken()
        let endpoint = PreApprovalEndpoint.status(referenceId: referenceId)
        
        return try await client.execute(endpoint, responseType: PreApprovalStatus.self, bearerToken: token)
    }
    
    /// Initiates a Pre-Approval and automatically polls until the user approves, rejects, or the request times out.
    public func requestPreApprovalAndWait(
        payload: PreApprovalRequest,
        maxAttempts: Int = 12,
        delayBetweenAttempts: Duration = .seconds(5)
    ) async throws -> PreApprovalStatus {
        let referenceId = try await requestPreApproval(payload: payload)
        var attempts = 0
        
        while attempts < maxAttempts {
            attempts += 1
            try await Task.sleep(for: delayBetweenAttempts)
            
            let status = try await getPreApprovalStatus(referenceId: referenceId)
            
            if status.transactionStatus != .pending {
                return status
            }
        }
        
        throw MoMoError.unexpectedResponse
    }
    
    /// Fetches all active Pre-Approval mandates targeting your service for a specific consumer.
    public func getPreApprovals(for party: Party) async throws -> [PreApprovalStatus] {
        let token = try await tokenProvider.getValidToken()
        let endpoint = PreApprovalEndpoint.list(party: party)
        
        return try await client.execute(endpoint, responseType: [PreApprovalStatus].self, bearerToken: token)
    }
    
    /// Cancels an existing Pre-Approval mandate.
    public func cancelPreApproval(referenceId: String) async throws {
        let token = try await tokenProvider.getValidToken()
        let endpoint = PreApprovalEndpoint.cancel(referenceId: referenceId)
        
        try await client.execute(endpoint, bearerToken: token)
    }
}
