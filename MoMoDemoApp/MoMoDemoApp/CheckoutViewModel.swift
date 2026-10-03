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
    
    init(client: MoMoCollectionClient) {
        self.client = client
    }
    
    func simulatePurchase(
        phoneNumber: String,
        amount: String,
        currency: String,
        payerMessage: String,
        payeeNote: String,
        deliveryNote: String
    ) async {
        self.isProcessing = true
        self.transactionStatus = "Initiating Request to Pay..."
        
        let payload = RequestToPayRequest(
            amount: amount,
            currency: currency,
            externalId: UUID().uuidString.lowercased(),
            payer: Party(partyIdType: .msisdn, partyId: phoneNumber),
            payerMessage: payerMessage,
            payeeNote: payeeNote
        )
        
        do {
            // 1. Initiate Request to Pay
            let referenceId = try await client.requestToPay(payload: payload)
            
            // 2. Conditionally send Delivery Notification
            if !deliveryNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.transactionStatus = "Sending Delivery Notification..."
                try await client.sendDeliveryNotification(for: referenceId, message: deliveryNote)
            }
            
            // 3. Poll for status
            self.transactionStatus = "Polling Transaction Status..."
            var finalStatus: RequestToPayStatus?
            
            for _ in 0..<12 {
                try await Task.sleep(for: .seconds(5))
                let current = try await client.getTransactionStatus(referenceId: referenceId)
                if current.status != .pending {
                    finalStatus = current
                    break
                }
            }
            
            guard let finalStatus = finalStatus else {
                self.transactionStatus = "Error: Polling timed out."
                self.isProcessing = false
                return
            }
            
            if finalStatus.status == .success || finalStatus.status == .successful {
                self.transactionStatus = "Success! ID: \(finalStatus.financialTransactionId ?? "")"
            } else {
                self.transactionStatus = "Failed: \(finalStatus.reason?.message ?? "Unknown Error")"
            }
        } catch {
            self.transactionStatus = "Error: \(error.localizedDescription)"
        }
        
        self.isProcessing = false
    }
}
