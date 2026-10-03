//
//  ContentView.swift
//  MoMoDemoApp
//
//  Created by kobby on 24/08/2026.
//

import SwiftUI
import MoMoCollections

struct ContentView: View {
    @EnvironmentObject var container: AppDependencyContainer
    @StateObject private var setupVM = SetUpViewModel()
    
    var body: some View {
        NavigationView {
            if setupVM.isKeyMissing {
                MissingKeyInstructionsView()
            } else if container.credentials != nil, let client = container.makeCollectionClient() {
                CheckoutView(client: client)
            } else {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Provisioning Sandbox...")
                        .foregroundColor(.secondary)
                    
                    if let error = setupVM.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                }
                .navigationTitle("Starting Demo")
                .onAppear {
                    Task { 
                        await setupVM.generateSandboxCredentials() 
                        if let creds = setupVM.credentials {
                            container.saveCredentials(creds)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Missing Key Instructions View
struct MissingKeyInstructionsView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)
            
            Text("Missing Subscription Key")
                .font(.title2)
                .bold()
            
            VStack(alignment: .leading, spacing: 16) {
                Text("To run this demo app, you must configure your Subscription Key:")
                
                HStack(alignment: .top) {
                    Text("1.")
                    Text("Open **MoMoConfig.swift** in Xcode.")
                }
                HStack(alignment: .top) {
                    Text("2.")
                    Text("Replace `YOUR_SUBSCRIPTION_KEY_HERE` with your primary key from the developer portal.")
                }
                HStack(alignment: .top) {
                    Text("3.")
                    Text("Rebuild and run the app.")
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            
            Spacer()
        }
        .padding(32)
        .navigationTitle("Setup Required")
    }
}

// MARK: - Checkout View
struct CheckoutView: View {
    @StateObject private var viewModel: CheckoutViewModel
    @State private var phoneNumber: String = "46733123453" // Standard MoMo sandbox test number
    @State private var amount: String = "50.00"
    @State private var currency: String = "EUR"
    @State private var payerMessage: String = "Demo App Purchase"
    @State private var payeeNote: String = "Test Transaction"
    @State private var deliveryNote: String = ""
    
    init(client: MoMoCollectionClient) {
        _viewModel = StateObject(wrappedValue: CheckoutViewModel(client: client))
    }
    
    var body: some View {
        Form {
            Section(header: Text("Payment Details")) {
                TextField("Phone Number", text: $phoneNumber)
                    .keyboardType(.phonePad)
                TextField("Amount", text: $amount)
                    .keyboardType(.decimalPad)
                TextField("Currency", text: $currency)
                    .autocapitalization(.allCharacters)
            }
            
            Section(header: Text("Notes & Messages")) {
                TextField("Payer Message", text: $payerMessage)
                TextField("Payee Note", text: $payeeNote)
                TextField("Delivery Note (Optional)", text: $deliveryNote)
            }
            
            Section {
                Button(action: {
                    Task { 
                        await viewModel.simulatePurchase(
                            phoneNumber: phoneNumber,
                            amount: amount,
                            currency: currency,
                            payerMessage: payerMessage,
                            payeeNote: payeeNote,
                            deliveryNote: deliveryNote
                        ) 
                    }
                }) {
                    if viewModel.isProcessing {
                        ProgressView().progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("Pay \(amount) \(currency)")
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
        .navigationTitle("Demo Store")
    }
}

#Preview {
    ContentView()
}
