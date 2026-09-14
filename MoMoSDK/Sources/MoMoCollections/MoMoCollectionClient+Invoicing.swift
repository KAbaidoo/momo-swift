//
//  MoMoCollectionClient+Invoicing.swift
//  MoMoSDK
//
//  Created by kobby on 14/09/2026.
//

import Foundation
import MoMoCore

extension MoMoCollectionClient {
    
    /// Creates a new invoice and returns the generated reference ID.
    public func createInvoice(
        payload: InvoiceRequest,
        referenceId: UUID = UUID(),
        callbackURL: String? = nil
    ) async throws -> String {
        let token = try await tokenProvider.getValidToken()
        let uuidString = referenceId.uuidString
        let endpoint = InvoiceEndpoint.create(
            referenceId: uuidString,
            payload: payload,
            callbackURL: callbackURL
        )
        
        try await client.execute(endpoint, bearerToken: token)
        return uuidString
    }
    
    /// Fetches the current status of a specific invoice.
    public func getInvoiceStatus(referenceId: String) async throws -> InvoiceStatus {
        let token = try await tokenProvider.getValidToken()
        let endpoint = InvoiceEndpoint.status(referenceId: referenceId)
        
        return try await client.execute(
            endpoint,
            responseType: InvoiceStatus.self,
            bearerToken: token
        )
    }
    
    /// Cancels a pending invoice.
    public func cancelInvoice(referenceId: String) async throws {
        let token = try await tokenProvider.getValidToken()
        let endpoint = InvoiceEndpoint.cancel(referenceId: referenceId)
        
        // DELETE returns 200 OK or 202 Accepted on success
        try await client.execute(endpoint, bearerToken: token)
    }
}
