import Foundation
import MoMoCore

extension MoMoCollectionClient {
    public func requestToWithdraw(payload: RequestToWithdrawRequest, referenceId: UUID = UUID(), callbackURL: String? = nil, version: WithdrawalVersion = .v1) async throws -> String {
        try CollectionValidation.money(payload.amount, payload.currency)
        try CollectionValidation.party(payload.payer)
        try MoMoValidation.callbackURL(callbackURL)
        try MoMoValidation.referenceId(referenceId.uuidString)
        let id = referenceId.uuidString.lowercased()
        return try await submit(WithdrawalEndpoint.initiate(referenceId: id, payload: payload, callbackURL: callbackURL, version: version), referenceId: id)
    }
    public func getWithdrawalStatus(referenceId: String) async throws -> RequestToWithdrawStatus {
        try await client.executeAuthenticated(WithdrawalEndpoint.status(referenceId: referenceId), responseType: RequestToWithdrawStatus.self, tokenProvider: tokenProvider)
    }
    public func waitForWithdrawal(referenceId: String, policy: MoMoPollingPolicy = .init()) async throws -> RequestToWithdrawStatus {
        try await MoMoPoller.poll(referenceId: referenceId, policy: policy, operation: { try await getWithdrawalStatus(referenceId: referenceId) }, isComplete: { $0.status.isTerminal })
    }
    public func requestToWithdrawAndWait(payload: RequestToWithdrawRequest, policy: MoMoPollingPolicy, referenceId: UUID = UUID(), callbackURL: String? = nil, version: WithdrawalVersion = .v1) async throws -> RequestToWithdrawStatus {
        try policy.validate()
        let id = try await requestToWithdraw(payload: payload, referenceId: referenceId, callbackURL: callbackURL, version: version)
        return try await waitForWithdrawal(referenceId: id, policy: policy)
    }
    @available(iOS 16, macOS 13, watchOS 9, tvOS 16, *)
    public func requestToWithdrawAndWait(payload: RequestToWithdrawRequest, maxAttempts: Int = 12, delayBetweenAttempts: Duration = .seconds(5)) async throws -> RequestToWithdrawStatus {
        try await requestToWithdrawAndWait(payload: payload, policy: Self.legacyPolicy(maxAttempts, delayBetweenAttempts))
    }
}
