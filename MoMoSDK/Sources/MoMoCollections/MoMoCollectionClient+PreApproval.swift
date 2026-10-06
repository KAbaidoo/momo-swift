import Foundation
import MoMoCore

extension MoMoCollectionClient {
    public func requestPreApproval(payload: PreApprovalRequest, referenceId: UUID = UUID(), callbackURL: String? = nil) async throws -> String {
        try CollectionValidation.party(payload.payer)
        try CollectionValidation.currency(payload.payerCurrency)
        try MoMoValidation.callbackURL(callbackURL)
        try MoMoValidation.referenceId(referenceId.uuidString)
        guard payload.validityTime > 0 else { throw CollectionValidationError.invalidValidity }
        let id = referenceId.uuidString.lowercased()
        return try await submit(PreApprovalEndpoint.initiate(referenceId: id, payload: payload, callbackURL: callbackURL), referenceId: id)
    }
    public func getPreApprovalStatus(referenceId: String) async throws -> PreApprovalStatus {
        try await client.executeAuthenticated(PreApprovalEndpoint.status(referenceId: referenceId), responseType: PreApprovalStatus.self, tokenProvider: tokenProvider)
    }
    public func waitForPreApproval(referenceId: String, policy: MoMoPollingPolicy = .init()) async throws -> PreApprovalStatus {
        try await MoMoPoller.poll(referenceId: referenceId, policy: policy, operation: { try await getPreApprovalStatus(referenceId: referenceId) }, isComplete: { $0.status.isTerminal })
    }
    public func requestPreApprovalAndWait(payload: PreApprovalRequest, policy: MoMoPollingPolicy, referenceId: UUID = UUID(), callbackURL: String? = nil) async throws -> PreApprovalStatus {
        try policy.validate()
        let id = try await requestPreApproval(payload: payload, referenceId: referenceId, callbackURL: callbackURL)
        return try await waitForPreApproval(referenceId: id, policy: policy)
    }
    @available(iOS 16, macOS 13, watchOS 9, tvOS 16, *)
    public func requestPreApprovalAndWait(payload: PreApprovalRequest, maxAttempts: Int = 12, delayBetweenAttempts: Duration = .seconds(5)) async throws -> PreApprovalStatus {
        try await requestPreApprovalAndWait(payload: payload, policy: Self.legacyPolicy(maxAttempts, delayBetweenAttempts))
    }
    public func getPreApprovals(identity: CollectionAccountIdentity) async throws -> [ApprovedPreApproval] {
        try await client.executeAuthenticated(PreApprovalEndpoint.list(identity: identity), responseType: [ApprovedPreApproval].self, tokenProvider: tokenProvider)
    }
    public func getPreApprovals(for party: Party) async throws -> [ApprovedPreApproval] {
        try await getPreApprovals(identity: CollectionAccountIdentity(party: party))
    }
    /// Use preApprovalId returned by the approved-mandate list, rather than its creation request ID.
    public func cancelPreApproval(preApprovalId: String) async throws {
        try await client.executeAuthenticated(PreApprovalEndpoint.cancel(preApprovalId: preApprovalId), tokenProvider: tokenProvider)
    }
    @available(*, deprecated, message: "Pass the system mandate ID to cancelPreApproval(preApprovalId:).")
    public func cancelPreApproval(referenceId: String) async throws { try await cancelPreApproval(preApprovalId: referenceId) }
}
