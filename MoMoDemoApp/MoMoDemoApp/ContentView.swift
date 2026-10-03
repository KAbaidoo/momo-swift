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
        if setupVM.isKeyMissing {
            NavigationView {
                MissingKeyInstructionsView()
            }
        } else if container.isReady, 
                  let collectionClient = container.makeCollectionClient(),
                  let disbursementClient = container.makeDisbursementClient() {
            
            TabView {
                NavigationView {
                    CheckoutView(client: collectionClient)
                }
                .tabItem {
                    Label("Collections", systemImage: "arrow.down.circle.fill")
                }
                
                DepositView(client: disbursementClient)
                    .tabItem {
                        Label("Disbursements", systemImage: "arrow.up.circle.fill")
                    }
            }
            .accentColor(MoMoTheme.darkBlue)
        } else {
            ZStack {
                MoMoTheme.background.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 32) {
                    Image(systemName: "bolt.horizontal.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(MoMoTheme.yellow)
                    
                    Text("MoMo SDK Demo")
                        .font(.largeTitle)
                        .fontWeight(.heavy)
                        .foregroundColor(MoMoTheme.darkBlue)
                }
                
                if setupVM.isProvisioning {
                    MoMoLoadingOverlay(message: "Provisioning Sandbox...")
                } else if let error = setupVM.errorMessage {
                    VStack {
                        Spacer()
                        Text("Setup Failed")
                            .font(.headline)
                            .foregroundColor(.red)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    .padding(.bottom, 40)
                }
            }
            .onAppear {
                Task { 
                    await setupVM.generateSandboxCredentials() 
                    if let colCreds = setupVM.collectionCredentials, let disCreds = setupVM.disbursementCredentials {
                        container.saveCredentials(collection: colCreds, disbursement: disCreds)
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
            
            Text("Missing Subscription Keys")
                .font(.title2)
                .bold()
            
            VStack(alignment: .leading, spacing: 16) {
                Text("To run this demo app, you must configure your Subscription Keys:")
                
                HStack(alignment: .top) {
                    Text("1.")
                    Text("Open **MoMoConfig.swift** in Xcode.")
                }
                HStack(alignment: .top) {
                    Text("2.")
                    Text("Replace `YOUR_COLLECTION_SUBSCRIPTION_KEY_HERE` and `YOUR_DISBURSEMENT_SUBSCRIPTION_KEY_HERE` with your primary keys from the developer portal.")
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
    @State private var phoneNumber: String = "46733123453"
    @State private var amount: String = "50.00"
    @State private var currency: String = "EUR"
    @State private var payerMessage: String = "Demo App Purchase"
    @State private var payeeNote: String = "Test Transaction"
    @State private var deliveryNote: String = ""
    
    init(client: MoMoCollectionClient) {
        _viewModel = StateObject(wrappedValue: CheckoutViewModel(client: client))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Logo
                VStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(MoMoTheme.yellow)
                    Text("Collections")
                        .font(.title)
                        .fontWeight(.bold)
                }
                .padding(.top, 24)
                
                VStack(spacing: 16) {
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .momoTextField(icon: "phone.fill")
                    
                    HStack(spacing: 16) {
                        TextField("Amount", text: $amount)
                            .keyboardType(.decimalPad)
                            .momoTextField(icon: "banknote.fill")
                        
                        TextField("Currency", text: $currency)
                            .autocapitalization(.allCharacters)
                            .frame(width: 80)
                            .momoTextField(icon: "dollarsign.circle.fill")
                    }
                }
                .padding(.horizontal)
                
                VStack(spacing: 16) {
                    TextField("Payer Message", text: $payerMessage)
                        .momoTextField(icon: "message.fill")
                    TextField("Payee Note", text: $payeeNote)
                        .momoTextField(icon: "doc.text.fill")
                    TextField("Delivery Note (Optional)", text: $deliveryNote)
                        .momoTextField(icon: "shippingbox.fill")
                }
                .padding(.horizontal)
                
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
                    Text("Pay \(amount) \(currency)")
                }
                .buttonStyle(PrimaryButtonStyle(isLoading: viewModel.isProcessing))
                .disabled(viewModel.isProcessing)
                .padding(.horizontal)
                .padding(.top, 16)
                
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
        .background(MoMoTheme.background.edgesIgnoringSafeArea(.all))
        .navigationBarHidden(true)
    }
}

#Preview {
    ContentView()
}
