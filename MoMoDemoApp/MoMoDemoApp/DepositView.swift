//
//  DepositView.swift
//  MoMoDemoApp
//
//  Created by kobby on 03/10/2026.
//

import SwiftUI
import MoMoDisbursements

struct DepositView: View {
    @StateObject private var viewModel: DepositViewModel
    @State private var phoneNumber: String = "46733123454"
    @State private var amount: String = "25.00"
    @State private var currency: String = "EUR"
    @State private var payerMessage: String = "Demo App Deposit"
    @State private var payeeNote: String = "Test Deposit"
    
    init(client: MoMoDisbursementClient) {
        _viewModel = StateObject(wrappedValue: DepositViewModel(client: client))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Recipient Details")) {
                    TextField("Phone Number", text: $phoneNumber).keyboardType(.phonePad)
                    TextField("Amount", text: $amount).keyboardType(.decimalPad)
                    TextField("Currency", text: $currency).autocapitalization(.allCharacters)
                }
                
                Section(header: Text("Notes")) {
                    TextField("Payer Message", text: $payerMessage)
                    TextField("Payee Note", text: $payeeNote)
                }
                
                Section {
                    Button(action: {
                        Task {
                            await viewModel.simulateDeposit(
                                phoneNumber: phoneNumber,
                                amount: amount,
                                currency: currency,
                                payerMessage: payerMessage,
                                payeeNote: payeeNote
                            )
                        }
                    }) {
                        if viewModel.isProcessing {
                            ProgressView().progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Deposit \(amount) \(currency)")
                        }
                    }
                    .disabled(viewModel.isProcessing)
                }
                
                Section(header: Text("Transaction Status")) {
                    Text(viewModel.transactionStatus)
                        .font(.callout)
                        .foregroundColor(viewModel.transactionStatus.contains("Success") ? .green : (viewModel.transactionStatus.contains("Error") || viewModel.transactionStatus.contains("Failed") ? .red : .primary))
                }
            }
            .navigationTitle("Disbursements")
        }
    }
}
