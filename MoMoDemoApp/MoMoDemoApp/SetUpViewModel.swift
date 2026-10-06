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
        !DemoConfiguration.hasSubscriptionKeys
    }
    
    func generateSandboxCredentials() async {
        guard !isKeyMissing, !isProvisioning else { return }
        
        isProvisioning = true
        defer { isProvisioning = false }
        self.errorMessage = nil
        
        do {
            // 1. Provision Collection Credentials
            if collectionCredentials == nil {
                let colProvisioner = MoMoSandboxProvisioner(subscriptionKey: DemoConfiguration.collectionSubscriptionKey)
                let (colUser, colKey) = try await colProvisioner.createSandboxCredentials()
                collectionCredentials = MoMoCredentials(apiUser: colUser, apiKey: colKey, subscriptionKey: DemoConfiguration.collectionSubscriptionKey)
            }
            
            // 2. Provision Disbursement Credentials
            if disbursementCredentials == nil {
                let disProvisioner = MoMoSandboxProvisioner(subscriptionKey: DemoConfiguration.disbursementSubscriptionKey)
                let (disUser, disKey) = try await disProvisioner.createSandboxCredentials()
                disbursementCredentials = MoMoCredentials(apiUser: disUser, apiKey: disKey, subscriptionKey: DemoConfiguration.disbursementSubscriptionKey)
            }
            try Task.checkCancellation()
        } catch is CancellationError {
            self.errorMessage = nil
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
    }
    
}
