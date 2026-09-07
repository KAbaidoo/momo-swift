//
//  MoMoCollectionClient+Account.swift
//  MoMoSDK
//
//  Created by kobby on 07/09/2026.
//

import Foundation
import MoMoCore

extension MoMoCollectionClient {
    
    /// Fetches the available balance of the Collection account.
    public func getAccountBalance() async throws -> AccountBalance {
        let token = try await tokenProvider.getValidToken()
        let endpoint = AccountEndpoint.getBalance
        
        return try await client.execute(endpoint, responseType: AccountBalance.self, bearerToken: token)
    }
    
    /// Checks if a customer's MoMo account is active and able to receive payment requests.
    /// Returns `true` if active. Throws an error (e.g., `MoMoError.resourceNotFound`) if inactive.
    public func isAccountHolderActive(party: Party) async throws -> Bool {
        let token = try await tokenProvider.getValidToken()
        let endpoint = AccountEndpoint.validateAccountHolder(party: party)
        
        do {
            // A 200 OK response means the account is active.
            try await client.execute(endpoint, bearerToken: token)
            return true
        } catch MoMoError.resourceNotFound {
            return false
        } catch {
            throw error
        }
    }
}
