import Foundation
import MoMoCore

extension MoMoCollectionClient {
    public func createPayment(payload: PaymentRequest, referenceId: UUID = UUID(), callbackURL: String? = nil) async throws -> String {
        try CollectionValidation.money(payload.money.amount, payload.money.currency)
        guard !payload.externalTransactionId.isEmpty, !payload.customerReference.isEmpty, !payload.serviceProviderUserName.isEmpty, (payload.maxNumberOfRetries ?? 0) >= 0 else { throw MoMoError.invalidConfiguration("Payment identifiers and retry count are invalid") }
        try MoMoValidation.callbackURL(callbackURL)
        try MoMoValidation.referenceId(referenceId.uuidString)
        let id = referenceId.uuidString.lowercased()
        return try await submit(PaymentEndpoint.create(referenceId: id, payload: payload, callbackURL: callbackURL), referenceId: id)
    }
    public func getPaymentStatus(referenceId: String) async throws -> PaymentStatus {
        try await client.executeAuthenticated(PaymentEndpoint.status(referenceId: referenceId), responseType: PaymentStatus.self, tokenProvider: tokenProvider)
    }
    public func waitForPayment(referenceId: String, policy: MoMoPollingPolicy = .init()) async throws -> PaymentStatus {
        try await MoMoPoller.poll(referenceId: referenceId, policy: policy, operation: { try await getPaymentStatus(referenceId: referenceId) }, isComplete: { $0.status.isTerminal })
    }
    public func createPaymentAndWait(payload: PaymentRequest, policy: MoMoPollingPolicy = .init(), referenceId: UUID = UUID(), callbackURL: String? = nil) async throws -> PaymentStatus {
        try policy.validate()
        let id = try await createPayment(payload: payload, referenceId: referenceId, callbackURL: callbackURL)
        return try await waitForPayment(referenceId: id, policy: policy)
    }
}
