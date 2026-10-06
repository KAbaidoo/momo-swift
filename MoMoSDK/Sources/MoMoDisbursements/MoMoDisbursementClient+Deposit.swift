import Foundation
import MoMoCore
extension MoMoDisbursementClient {

    /// Submit once with a caller-owned reference ID for reconciliation.
    public func deposit(payload: DepositRequest, referenceId: UUID = UUID(), callbackURL: String? = nil, version: DisbursementAPIVersion = .v1) async throws -> String {
        try PayoutValidation.money(amount: payload.amount, currency: payload.currency)
        try PayoutValidation.party(payload.payee)
        try PayoutValidation.callback(callbackURL)
        let id = referenceId.uuidString.lowercased()
        try MoMoValidation.referenceId(id)
        do { try await client.executeAuthenticated(DepositEndpoint.initiate(referenceId: id, payload: payload, callbackURL: callbackURL, version: version), tokenProvider: tokenProvider) }
        catch { throw MoMoError.transactionFailure(referenceId: id, underlying: error) }
        return id
    }
    public func getDepositStatus(referenceId: String) async throws -> DepositStatus {
        try PayoutValidation.reference(referenceId)
        return try await client.executeAuthenticated(DepositEndpoint.status(referenceId: referenceId), responseType: DepositStatus.self, tokenProvider: tokenProvider)
    }
    public func depositAndWait(payload: DepositRequest, referenceId: UUID = UUID(), callbackURL: String? = nil, version: DisbursementAPIVersion = .v1, policy: MoMoPollingPolicy) async throws -> DepositStatus {
        try policy.validate()
        let id = try await deposit(payload: payload, referenceId: referenceId, callbackURL: callbackURL, version: version)
        return try await MoMoPoller.poll(referenceId: id, policy: policy, operation: { try await getDepositStatus(referenceId: id) }, isComplete: { $0.status?.isTerminal == true })
    }
    @available(iOS 16, macOS 13, watchOS 9, tvOS 16, *)
    public func depositAndWait(payload: DepositRequest, maxAttempts: Int = 12, delayBetweenAttempts: Duration = .seconds(5)) async throws -> DepositStatus {
        let c = delayBetweenAttempts.components
        let interval = Double(c.seconds) + Double(c.attoseconds) / 1e18
        return try await depositAndWait(payload: payload, policy: MoMoPollingPolicy(maxAttempts: maxAttempts, interval: interval, backoffMultiplier: 1, maximumInterval: max(0, interval)))
    }
}
