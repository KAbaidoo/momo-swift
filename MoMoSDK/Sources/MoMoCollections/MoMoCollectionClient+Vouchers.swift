//
//  MoMoCollectionClient+Voucher.swift
//  MoMoSDK
//
//  Created by kobby on 15/09/2026.
//

import Foundation
import MoMoCore


extension MoMoCollectionClient {
    /// Creates a new voucher and returns the generated reference ID.
    public func createVoucher(payload: VoucherRequest, referenceId: UUID = UUID(), callbackURL: String? = nil) async throws -> String {
        let token = try await tokenProvider.getValidToken()
        let uuidString = referenceId.uuidString
        let endpoint = VoucherEndpoint.create(referenceId: uuidString, payload: payload, callbackURL: callbackURL)
        
        try await client.execute(endpoint, bearerToken: token)
        return uuidString
    }
    
    /// Fetches the current status and details of a specific voucher.
    public func getVoucherStatus(referenceId: String) async throws -> VoucherStatus {
        let token = try await tokenProvider.getValidToken()
        let endpoint = VoucherEndpoint.status(referenceId: referenceId)
        
        return try await client.execute(endpoint, responseType: VoucherStatus.self, bearerToken: token)
    }
    
    /// Cancel a previously generated voucher.
    public func cancelVoucher(referenceId: String) async throws {
        let token = try await tokenProvider.getValidToken()
        let endpoint = VoucherEndpoint.cancel(referenceId: referenceId)
        
        // The DELETE method typically returns a 200 OK or 202 Accepted without a body requirement.
        try await client.execute(endpoint, bearerToken: token)
    }
}
