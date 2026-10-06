//
//  DepositView.swift
//  MoMoDemoApp
//
//  Created by kobby on 03/10/2026.
//

import SwiftUI
import MoMoDisbursements

struct DepositView: View {
    enum Field {
        case phone, amount, currency, payerMessage, payeeNote
    }

    @StateObject private var viewModel: DepositViewModel
    @State private var phoneNumber: String = "46733123470"
    @State private var amount: String = "25.00"
    @State private var currency: String = "EUR"
    @State private var payerMessage: String = "Demo App Deposit"
    @State private var payeeNote: String = "Test Deposit"
    
    @FocusState private var focusedField: Field?
    @State private var transactionTask: Task<Void, Never>?
    
    init(client: MoMoDisbursementClient) {
        _viewModel = StateObject(wrappedValue: DepositViewModel(client: client))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Logo
                VStack(spacing: 8) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(MoMoTheme.yellow)
                    Text("Disbursements")
                        .font(.title)
                        .fontWeight(.bold)
                }
                .padding(.top, 24)
                
                VStack(spacing: 16) {
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .focused($focusedField, equals: .phone)
                        .momoTextField(icon: "phone.fill")
                    
                    HStack(spacing: 16) {
                        TextField("Amount", text: $amount)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .amount)
                            .momoTextField(icon: "banknote.fill")
                        
                        TextField("Currency", text: $currency)
                            .autocapitalization(.allCharacters)
                            .focused($focusedField, equals: .currency)
                            .frame(width: 80)
                            .momoTextField(icon: "dollarsign.circle.fill")
                    }
                }
                .padding(.horizontal)
                
                VStack(spacing: 16) {
                    TextField("Payer Message", text: $payerMessage)
                        .focused($focusedField, equals: .payerMessage)
                        .momoTextField(icon: "message.fill")
                    TextField("Payee Note", text: $payeeNote)
                        .focused($focusedField, equals: .payeeNote)
                        .momoTextField(icon: "doc.text.fill")
                }
                .padding(.horizontal)
                
                Button(action: {
                    focusedField = nil
                    transactionTask = Task {
                        await viewModel.simulateDeposit(
                            phoneNumber: phoneNumber,
                            amount: amount,
                            currency: currency,
                            payerMessage: payerMessage,
                            payeeNote: payeeNote
                        )
                    }
                }) {
                    Text("Deposit \(amount) \(currency)")
                }
                .buttonStyle(PrimaryButtonStyle(isLoading: viewModel.isProcessing))
                .disabled(viewModel.isProcessing || viewModel.hasUnresolvedRequest)
                .padding(.horizontal)
                .padding(.top, 16)
                
                if viewModel.referenceId != nil {
                    Button("Check existing request") {
                        transactionTask = Task { await viewModel.checkExistingRequest() }
                    }
                    .disabled(viewModel.isProcessing)
                }

                if viewModel.transactionStatus != "Idle" {
                    VStack(spacing: 8) {
                        Text("Transaction Status")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(viewModel.transactionStatus)
                            .font(.body)
                            .bold()
                            .foregroundColor(viewModel.transactionStatus.contains("Success") ? .green : (viewModel.transactionStatus.contains("Error") || viewModel.transactionStatus.contains("Failed") ? .red : .primary))
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 40)
        }
        .onDisappear { transactionTask?.cancel() }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
            }
        }
        .background(MoMoTheme.background.edgesIgnoringSafeArea(.all))
        .navigationBarHidden(true)
    }
}
