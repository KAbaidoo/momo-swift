//
//  CheckoutViewModel.swift
//  MoMoDemoApp
//
//  Created by kobby on 28/09/2026.
//

import Foundation
import Combine
import MoMoCore
import MoMoCollections


@MainActor
class CheckoutViewModel: ObservableObject {
    @Published var transactionStatus: String = "Idle"
    @Published var isProcessing: Bool = false
    
    let client: MoMoCollectionClient
    
    init(credentials: MoMoCredentials) {
        
        self.client = MoMoCollectionClient(credentials: credentials, environment: .sandbox)
    }
    
    func simulatePurchase(phoneNumber: String, amount: String) async {
        self.isProcessing = true
        self.transactionStatus = "Initiating Request to Pay..."
        
        let payload = RequestToPayRequest(
                    amount: amount,
                    currency: "EUR", // Default sandbox currency
                    externalId: UUID().uuidString.lowercased(),
                    payer: Party(partyIdType: .msisdn, partyId: phoneNumber),
                    payerMessage: "Demo App Purchase",
                    payeeNote: "Test Transaction"
                )
                
                do {
                    // Demonstrates the auto-polling feature yielding thread control
                    let finalStatus = try await client.requestToPayAndWait(payload: payload)
                    
                    if finalStatus.status == .success {
                        self.transactionStatus = "Success! ID: \(finalStatus.financialTransactionId ?? "")"
                    } else {
                        self.transactionStatus = "Failed: \(finalStatus.reason?.message ?? "Unknown")"
                    }
                } catch {
                    self.transactionStatus = "Error: \(error.localizedDescription)"
                }
                
                self.isProcessing = false
    }
}
