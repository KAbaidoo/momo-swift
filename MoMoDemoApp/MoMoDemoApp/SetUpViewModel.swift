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
    @Published var subscriptionKey: String = MoMoConfig.subscriptionKey
    @Published var credentials: MoMoCredentials?
    @Published var errorMessage: String?
    @Published var isProvisioning: Bool = false
    
    var isKeyMissing: Bool {
        subscriptionKey == "YOUR_SUBSCRIPTION_KEY_HERE" || subscriptionKey.isEmpty
    }
    
    func generateSandboxCredentials() async {
        guard !isKeyMissing else { return }
        
        isProvisioning = true
        self.errorMessage = nil
        
        let provisioner = MoMoSandboxProvisioner(subscriptionKey: subscriptionKey)
        
        do {
            // Generates the UUID and fetches the API Key in one automated flow
            let (apiUser, apiKey) = try await provisioner.createSandboxCredentials()
            self.credentials = MoMoCredentials(apiUser: apiUser, apiKey: apiKey, subscriptionKey: subscriptionKey)
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isProvisioning = false
    }
    
}
