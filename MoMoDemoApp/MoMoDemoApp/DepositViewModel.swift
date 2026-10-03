//
//  DepositViewModel.swift
//  MoMoDemoApp
//
//  Created by kobby on 03/10/2026.
//

import Foundation
import Combine
import MoMoCore
import MoMoDisbursements

@MainActor
class DepositViewModel: ObservableObject {
    @Published var transactionStatus: String = "Idle"
    @Published var isProcessing: Bool = false
    
    let client: MoMoDisbursementClient
    
    init(client: MoMoDisbursementClient) {
        self.client = client
    }
    
    func simulateDeposit(
        phoneNumber: String,
        amount: String,
        currency: String,
        payerMessage: String,
        payeeNote: String
    ) async {
        self.isProcessing = true
        self.transactionStatus = "Initiating Deposit..."
        
        let payload = DepositRequest(
            amount: amount,
            currency: currency,
            externalId: UUID().uuidString.lowercased(),
            payee: Party(partyIdType: .msisdn, partyId: phoneNumber),
            payerMessage: payerMessage,
            payeeNote: payeeNote
        )
        
        do {
            let finalStatus = try await client.depositAndWait(payload: payload)
            
            if finalStatus.status == .successful {
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
