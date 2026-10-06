import Foundation
import MoMoCore

/// Collections operations use product credentials. Persist reference IDs before submitting payments.
public struct MoMoCollectionClient: Sendable {
    internal let client: MoMoAPIClient
    internal let tokenProvider: MoMoTokenProvider

    public init(credentials: MoMoCredentials, environment: MoMoEnvironment,
                transport: any MoMoHTTPTransport = MoMoURLSessionTransport(), retryPolicy: MoMoRetryPolicy = .default) {
        let client = MoMoAPIClient(environment: environment, subscriptionKey: credentials.subscriptionKey, transport: transport, retryPolicy: retryPolicy)
        self.init(client: client, tokenProvider: MoMoTokenProvider(apiUser: credentials.apiUser, apiKey: credentials.apiKey, tokenPath: "/collection/token/", client: client))
    }

    public init(client: MoMoAPIClient, tokenProvider: MoMoTokenProvider) {
        self.client = client
        self.tokenProvider = tokenProvider
    }

    internal func submit(_ endpoint: any MoMoEndpoint, referenceId: String) async throws -> String {
        do { try await client.executeAuthenticated(endpoint, tokenProvider: tokenProvider); return referenceId }
        catch { throw MoMoError.transactionFailure(referenceId: referenceId, underlying: error) }
    }

    public func requestToPay(payload: RequestToPayRequest, referenceId: UUID = UUID(), callbackURL: String? = nil) async throws -> String {
        try CollectionValidation.money(payload.amount, payload.currency)
        try CollectionValidation.party(payload.payer)
        try MoMoValidation.callbackURL(callbackURL)
        try MoMoValidation.referenceId(referenceId.uuidString)
        let id = referenceId.uuidString.lowercased()
        return try await submit(RequestToPayEndpoint.initiate(referenceId: id, payload: payload, callbackURL: callbackURL), referenceId: id)
    }

    public func getTransactionStatus(referenceId: String) async throws -> RequestToPayStatus {
        try await client.executeAuthenticated(RequestToPayEndpoint.status(referenceId: referenceId), responseType: RequestToPayStatus.self, tokenProvider: tokenProvider)
    }

    public func waitForRequestToPay(referenceId: String, policy: MoMoPollingPolicy = .init()) async throws -> RequestToPayStatus {
        try await MoMoPoller.poll(referenceId: referenceId, policy: policy, operation: { try await getTransactionStatus(referenceId: referenceId) }, isComplete: { $0.status.isTerminal })
    }

    public func requestToPayAndWait(payload: RequestToPayRequest, policy: MoMoPollingPolicy, referenceId: UUID = UUID(), callbackURL: String? = nil) async throws -> RequestToPayStatus {
        try policy.validate()
        let id = try await requestToPay(payload: payload, referenceId: referenceId, callbackURL: callbackURL)
        return try await waitForRequestToPay(referenceId: id, policy: policy)
    }

    @available(iOS 16, macOS 13, watchOS 9, tvOS 16, *)
    public func requestToPayAndWait(payload: RequestToPayRequest, maxAttempts: Int = 12, delayBetweenAttempts: Duration = .seconds(5)) async throws -> RequestToPayStatus {
        try await requestToPayAndWait(payload: payload, policy: Self.legacyPolicy(maxAttempts, delayBetweenAttempts))
    }

    @available(iOS 16, macOS 13, watchOS 9, tvOS 16, *)
    internal static func legacyPolicy(_ attempts: Int, _ delay: Duration) -> MoMoPollingPolicy {
        let c = delay.components
        let seconds = Double(c.seconds) + Double(c.attoseconds) / 1e18
        return .init(maxAttempts: attempts, interval: seconds, backoffMultiplier: 1, maximumInterval: seconds)
    }

    /// Call only after the transaction succeeds. Notification failure does not reverse payment.
    public func sendDeliveryNotification(for referenceId: String, message: String, language: String? = nil) async throws {
        guard !message.isEmpty, !message.contains(where: { $0.isNewline }) else { throw CollectionValidationError.invalidNotificationMessage }
        if let language, language.isEmpty || language.contains(where: { $0.isNewline }) { throw CollectionValidationError.invalidLanguage }
        try await client.executeAuthenticated(RequestToPayEndpoint.deliveryNotification(referenceId: referenceId, payload: .init(notificationMessage: message), language: language), tokenProvider: tokenProvider)
    }
}
