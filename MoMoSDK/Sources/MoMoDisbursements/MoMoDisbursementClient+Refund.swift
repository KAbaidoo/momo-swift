//
//  MoMoDisbursementClient+Refund.swift
//  MoMoSDK
//
//  Created by kobby on 25/09/2026.
//

import Foundation
import MoMoCore

extension MoMoDisbursementClient {
    
    /// Initiates a Refund for a previous disbursement transaction.
    public func refund(payload: RefundRequest, referenceId: UUID = UUID(), callbackURL: String? = nil) async throws -> String {
        let token = try await tokenProvider.getValidToken()
        let uuidString = referenceId.uuidString
        let endpoint = RefundEndpoint.initiate(referenceId: uuidString, payload: payload, callbackURL: callbackURL)
        
        try await client.execute(endpoint, bearerToken: token)
        return uuidString
    }
    
    /// Fetches the status of a Refund transaction.
    public func getRefundStatus(referenceId: String) async throws -> RefundStatus {
        let token = try await tokenProvider.getValidToken()
        let endpoint = RefundEndpoint.status(referenceId: referenceId)
        
        return try await client.execute(
            endpoint,
            responseType: RefundStatus.self,
            bearerToken: token
        )
    }
    
    /// Initiates a Refund and continuously polls until it reaches a final state.
    public func refundAndWait(
        payload: RefundRequest,
        maxAttempts: Int = 12,
        delayBetweenAttempts: Duration = .seconds(5)
    ) async throws -> RefundStatus {
        let referenceId = try await refund(payload: payload)
        var attempts = 0
        
        while attempts < maxAttempts {
            attempts += 1
            try await Task.sleep(for: delayBetweenAttempts)
            
            let status = try await getRefundStatus(referenceId: referenceId)
            if status.status != .pending { return status }
        }
        
        throw MoMoError.unexpectedResponse
    }
}
