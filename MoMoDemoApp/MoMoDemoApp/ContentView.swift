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
        if container.isReady,
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
        } else if setupVM.isKeyMissing {
            NavigationView { MissingKeyInstructionsView() }
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
                        Button("Retry setup") { setupVM.errorMessage = nil }
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    .padding(.bottom, 40)
                }
            }
            .task(id: setupVM.errorMessage == nil) {
                guard setupVM.errorMessage == nil else { return }
                await setupVM.generateSandboxCredentials()
                guard !Task.isCancelled else { return }
                if let colCreds = setupVM.collectionCredentials, let disCreds = setupVM.disbursementCredentials {
                    do { try container.saveCredentials(collection: colCreds, disbursement: disCreds) }
                    catch { setupVM.errorMessage = error.localizedDescription }
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
                    Text("Open Product → Scheme → Edit Scheme → Run → Arguments in Xcode.")
                }
                HStack(alignment: .top) {
                    Text("2.")
                    Text("Add MOMO_COLLECTION_SUBSCRIPTION_KEY and MOMO_DISBURSEMENT_SUBSCRIPTION_KEY as environment variables using your sandbox subscription keys.")
                }
                HStack(alignment: .top) {
                    Text("3.")
                    Text("Keep the scheme private, then run the app.")
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
    enum Field {
        case phone, amount, currency, payerMessage, payeeNote, deliveryNote
    }
    
    @StateObject private var viewModel: CheckoutViewModel
    @State private var phoneNumber: String = "46733123470"
    @State private var amount: String = "50.00"
    @State private var currency: String = "EUR"
    @State private var payerMessage: String = "Demo App Purchase"
    @State private var payeeNote: String = "Test Transaction"
    @State private var deliveryNote: String = ""
    
    @FocusState private var focusedField: Field?
    @State private var transactionTask: Task<Void, Never>?
    
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
                    TextField("Delivery Note (Optional)", text: $deliveryNote)
                        .focused($focusedField, equals: .deliveryNote)
                        .momoTextField(icon: "shippingbox.fill")
                }
                .padding(.horizontal)
                
                Button(action: {
                    focusedField = nil
                    transactionTask = Task {
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

#Preview {
    ContentView().environmentObject(AppDependencyContainer())
}
