import Foundation
import MoMoCore
extension MoMoDisbursementClient {

    /// Submit once with a caller-owned reference ID for reconciliation.
    public func refund(payload: RefundRequest, referenceId: UUID = UUID(), callbackURL: String? = nil, version: DisbursementAPIVersion = .v1) async throws -> String {
        try PayoutValidation.money(amount: payload.amount, currency: payload.currency)
        try PayoutValidation.reference(payload.referenceIdToRefund)
        try PayoutValidation.callback(callbackURL)
        let id = referenceId.uuidString.lowercased()
        try MoMoValidation.referenceId(id)
        do { try await client.executeAuthenticated(RefundEndpoint.initiate(referenceId: id, payload: payload, callbackURL: callbackURL, version: version), tokenProvider: tokenProvider) }
        catch { throw MoMoError.transactionFailure(referenceId: id, underlying: error) }
        return id
    }
    public func getRefundStatus(referenceId: String) async throws -> RefundStatus {
        try PayoutValidation.reference(referenceId)
        return try await client.executeAuthenticated(RefundEndpoint.status(referenceId: referenceId), responseType: RefundStatus.self, tokenProvider: tokenProvider)
    }
    public func refundAndWait(payload: RefundRequest, referenceId: UUID = UUID(), callbackURL: String? = nil, version: DisbursementAPIVersion = .v1, policy: MoMoPollingPolicy) async throws -> RefundStatus {
        try policy.validate()
        let id = try await refund(payload: payload, referenceId: referenceId, callbackURL: callbackURL, version: version)
        return try await MoMoPoller.poll(referenceId: id, policy: policy, operation: { try await getRefundStatus(referenceId: id) }, isComplete: { $0.status?.isTerminal == true })
    }
    @available(iOS 16, macOS 13, watchOS 9, tvOS 16, *)
    public func refundAndWait(payload: RefundRequest, maxAttempts: Int = 12, delayBetweenAttempts: Duration = .seconds(5)) async throws -> RefundStatus {
        let c = delayBetweenAttempts.components
        let interval = Double(c.seconds) + Double(c.attoseconds) / 1e18
        return try await refundAndWait(payload: payload, policy: MoMoPollingPolicy(maxAttempts: maxAttempts, interval: interval, backoffMultiplier: 1, maximumInterval: max(0, interval)))
    }
}
