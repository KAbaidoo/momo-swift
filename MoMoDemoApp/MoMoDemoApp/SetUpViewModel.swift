//
//  SetUpViewModel.swift
//  MoMoDemoApp
//
//  Created by kobby on 28/09/2026.
//

import Foundation
import MoMoCore
import Combine

@MainActor
public class SetUpViewModel: ObservableObject {
    @Published var collectionCredentials: MoMoCredentials?
    @Published var disbursementCredentials: MoMoCredentials?
    @Published var errorMessage: String?
    @Published var isProvisioning: Bool = false
    
    var isKeyMissing: Bool {
        MoMoConfig.collectionSubscriptionKey == "YOUR_COLLECTION_SUBSCRIPTION_KEY_HERE" || MoMoConfig.collectionSubscriptionKey.isEmpty ||
        MoMoConfig.disbursementSubscriptionKey == "YOUR_DISBURSEMENT_SUBSCRIPTION_KEY_HERE" || MoMoConfig.disbursementSubscriptionKey.isEmpty
    }
    
    func generateSandboxCredentials() async {
        guard !isKeyMissing else { return }
        
        isProvisioning = true
        self.errorMessage = nil
        
        do {
            // 1. Provision Collection Credentials
            let colProvisioner = MoMoSandboxProvisioner(subscriptionKey: MoMoConfig.collectionSubscriptionKey)
            let (colUser, colKey) = try await colProvisioner.createSandboxCredentials()
            let colCreds = MoMoCredentials(apiUser: colUser, apiKey: colKey, subscriptionKey: MoMoConfig.collectionSubscriptionKey)
            
            // 2. Provision Disbursement Credentials
            let disProvisioner = MoMoSandboxProvisioner(subscriptionKey: MoMoConfig.disbursementSubscriptionKey)
            let (disUser, disKey) = try await disProvisioner.createSandboxCredentials()
            let disCreds = MoMoCredentials(apiUser: disUser, apiKey: disKey, subscriptionKey: MoMoConfig.disbursementSubscriptionKey)
            
            self.collectionCredentials = colCreds
            self.disbursementCredentials = disCreds
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isProvisioning = false
    }
    
}
