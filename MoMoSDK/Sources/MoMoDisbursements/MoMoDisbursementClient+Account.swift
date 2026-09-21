//
//  DisbursementClient+Account.swift
//  MoMoSDK
//
//  Created by kobby on 21/09/2026.
//

import Foundation
import MoMoCore

extension MoMoDisbursementClient {
    /// Fetches the available balance of the disbursement account
    public func getAccountBalance() async throws -> AccountBalance {
        let token = try await tokenProvider.getValidToken()
        let endpoint = DisbursementAccountEndpoint.getBalance
        
        return try await client.execute(endpoint, responseType: AccountBalance.self, bearerToken: token)
        
    }
    
    /// Checks if a customer's MoMo account is active and is able to receive transfers.
    public func isAccountHolderActive(party: Party) async throws -> Bool {
        let token = try await tokenProvider.getValidToken()
        let endpoint = DisbursementAccountEndpoint.validateAccountHolder(party: party)
        
        do {
            try await client.execute(endpoint, bearerToken: token)
            return true
        } catch MoMoError.resourceNotFound {
            return false
        } catch {
            throw error
        }
    }
    
}
