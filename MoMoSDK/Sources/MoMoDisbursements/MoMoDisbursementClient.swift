import Foundation
import MoMoCore

public struct MoMoDisbursementClient: Sendable {
    let client: MoMoAPIClient
    let tokenProvider: MoMoTokenProvider
    public init(credentials: MoMoCredentials, environment: MoMoEnvironment) {
        let client = MoMoAPIClient(environment: environment, subscriptionKey: credentials.subscriptionKey)
        self.init(client: client, tokenProvider: MoMoTokenProvider(apiUser: credentials.apiUser, apiKey: credentials.apiKey, tokenPath: "/disbursement/token/", client: client))
    }
    public init(credentials: MoMoCredentials, environment: MoMoEnvironment, transport: any MoMoHTTPTransport, retryPolicy: MoMoRetryPolicy = .default) {
        let client = MoMoAPIClient(environment: environment, subscriptionKey: credentials.subscriptionKey, transport: transport, retryPolicy: retryPolicy)
        self.init(client: client, tokenProvider: MoMoTokenProvider(apiUser: credentials.apiUser, apiKey: credentials.apiKey, tokenPath: "/disbursement/token/", client: client))
    }
    public init(client: MoMoAPIClient, tokenProvider: MoMoTokenProvider) { self.client = client; self.tokenProvider = tokenProvider }

    /// Submit once with a caller-owned reference ID for reconciliation.
    public func transfer(payload: TransferRequest, referenceId: UUID = UUID(), callbackURL: String? = nil) async throws -> String {
        try PayoutValidation.money(amount: payload.amount, currency: payload.currency)
        try PayoutValidation.party(payload.payee)
        try PayoutValidation.callback(callbackURL)
        let id = referenceId.uuidString.lowercased()
        try MoMoValidation.referenceId(id)
        do { try await client.executeAuthenticated(TransferEndpoint.initiate(referenceId: id, payload: payload, callbackURL: callbackURL), tokenProvider: tokenProvider) }
        catch { throw MoMoError.transactionFailure(referenceId: id, underlying: error) }
        return id
    }
    public func getTransferStatus(referenceId: String) async throws -> TransferStatus {
        try PayoutValidation.reference(referenceId)
        return try await client.executeAuthenticated(TransferEndpoint.status(referenceId: referenceId), responseType: TransferStatus.self, tokenProvider: tokenProvider)
    }
    public func transferAndWait(payload: TransferRequest, referenceId: UUID = UUID(), callbackURL: String? = nil, policy: MoMoPollingPolicy) async throws -> TransferStatus {
        try policy.validate()
        let id = try await transfer(payload: payload, referenceId: referenceId, callbackURL: callbackURL)
        return try await MoMoPoller.poll(referenceId: id, policy: policy, operation: { try await getTransferStatus(referenceId: id) }, isComplete: { $0.status?.isTerminal == true })
    }
    @available(iOS 16, macOS 13, watchOS 9, tvOS 16, *)
    public func transferAndWait(payload: TransferRequest, maxAttempts: Int = 12, delayBetweenAttempts: Duration = .seconds(5)) async throws -> TransferStatus {
        let c = delayBetweenAttempts.components
        let interval = Double(c.seconds) + Double(c.attoseconds) / 1e18
        return try await transferAndWait(payload: payload, policy: MoMoPollingPolicy(maxAttempts: maxAttempts, interval: interval, backoffMultiplier: 1, maximumInterval: max(0, interval)))
    }
}
