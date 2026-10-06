import Foundation
import MoMoSDK

// Compile the public umbrella API from an independent package. No requests run.
let credentials = MoMoCredentials(apiUser: "example-user", apiKey: "example-key", subscriptionKey: "example-subscription")
let collection = MoMoCollectionClient(credentials: credentials, environment: .sandbox)
let disbursement = MoMoDisbursementClient(credentials: credentials, environment: .sandbox)
let remittance = MoMoRemittanceClient(credentials: credentials, environment: .sandbox)
let payer = Party(partyIdType: .msisdn, partyId: "46733123470")
let request = RequestToPayRequest(amount: "12.50", currency: "EUR", externalId: "order-1", payer: payer,
                                payerMessage: "Order 1", payeeNote: "Order 1")
let policy = MoMoPollingPolicy()
_ = (collection, disbursement, remittance, request, policy)
print("MoMoSDK public API compiled successfully.")

// These examples are type-checked but are never invoked by the smoke executable.
func documentationExamples() async throws {
    let reference = UUID()
    _ = try await collection.requestToPay(payload: request, referenceId: reference)
    let result = try await collection.waitForRequestToPay(referenceId: reference.uuidString)
    _ = result.status == .successful
    _ = try await disbursement.getAccountBalance(currency: "EUR")
    _ = try await remittance.transfer(payload: RemittanceTransferRequest(amount: "10.00", currency: "EUR", payee: payer), referenceId: UUID())
    _ = try await collection.createInvoice(payload: InvoiceRequest(externalId: "order", amount: "10.00", currency: "EUR", validityDuration: "60", intendedPayer: payer, payee: payer))
    let consent = MoMoConsentClient(credentials: credentials, product: .disbursement)
    let authorization = try await consent.authorize(loginHint: "ID:46733123470/MSISDN", scopes: ["openid"], accessType: .offline)
    let token = try await consent.exchange(authRequestId: authorization.authRequestId)
    _ = try await consent.userInfo(accessToken: token.accessToken)
}
