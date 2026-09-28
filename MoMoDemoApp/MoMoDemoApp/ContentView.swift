//
//  ContentView.swift
//  MoMoDemoApp
//
//  Created by kobby on 24/08/2026.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var setupVM = SetUpViewModel()
    
    var body: some View {
        NavigationView {
            if let credentials = setupVM.credentials {
                CheckoutView(viewModel: CheckoutViewModel(credentials: credentials))
            } else {
                SandboxSetupView(viewModel: setupVM)
            }
        }
    }
}

// MARK: - Sandbox Setup View
struct SandboxSetupView: View {
    @ObservedObject var viewModel: SetUpViewModel
    
    var body: some View {
        Form {
            Section(header: Text("Sandbox Configuration")) {
                TextField("Primary Subscription Key", text: $viewModel.subscriptionKey)
                
                Button(action: {
                    Task { await viewModel.generateSandboxCredentials() }
                }) {
                    Text("Provision API User & Key")
                        .bold()
                }
                .disabled(viewModel.subscriptionKey.isEmpty)
            }
            
            if let error = viewModel.errorMessage {
                Text(error).foregroundColor(.red)
            }
        }
        .navigationTitle("MoMo Setup")
    }
}

// MARK: - Checkout View
struct CheckoutView: View {
    @ObservedObject var viewModel: CheckoutViewModel
    @State private var phoneNumber: String = "46733123453" // Standard MoMo sandbox test number
    
    var body: some View {
        Form {
            Section(header: Text("Checkout")) {
                TextField("Phone Number", text: $phoneNumber)
                
                Button(action: {
                    Task { await viewModel.simulatePurchase(phoneNumber: phoneNumber, amount: "50.00") }
                }) {
                    if viewModel.isProcessing {
                        ProgressView().progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("Pay 50.00 EUR")
                    }
                }
                .disabled(viewModel.isProcessing)
            }
            
            Section(header: Text("Transaction Status")) {
                Text(viewModel.transactionStatus)
                    .font(.callout)
                    .foregroundColor(viewModel.transactionStatus.contains("Success") ? .green : .primary)
            }
        }
        .navigationTitle("Demo Store")
    }
}

#Preview {
    ContentView()
}
