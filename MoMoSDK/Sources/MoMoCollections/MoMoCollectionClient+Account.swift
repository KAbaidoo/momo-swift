import Foundation
import MoMoCore

extension MoMoCollectionClient {
    public func getAccountBalance() async throws -> AccountBalance {
        return try await client.executeAuthenticated(AccountEndpoint.getBalance, responseType: AccountBalance.self, tokenProvider: tokenProvider)
    }
    public func getAccountBalance(currency: String) async throws -> AccountBalance {
        try CollectionValidation.currency(currency)
        return try await client.executeAuthenticated(AccountEndpoint.currencyBalance(currency), responseType: AccountBalance.self, tokenProvider: tokenProvider)
    }
    /// The published response description allows false under HTTP 200.
    public func isAccountHolderActive(party: Party) async throws -> Bool {
        try CollectionValidation.party(party)
        _ = try CollectionAccountIdentity(party: party)
        do { return try await client.executeAuthenticated(AccountEndpoint.validateAccountHolder(party: party), responseType: CollectionActiveResult.self, tokenProvider: tokenProvider).result }
        catch let error as MoMoError where error.statusCode == 404 { return false }
    }
    public func getBasicUserInfo(identity: CollectionAccountIdentity) async throws -> BasicUserInfo {
        guard !identity.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw MoMoError.invalidConfiguration("Account identifier is empty") }
        return try await client.executeAuthenticated(AccountEndpoint.getBasicUserInfo(identity: identity), responseType: BasicUserInfo.self, tokenProvider: tokenProvider)
    }
    public func getBasicUserInfo(party: Party) async throws -> BasicUserInfo {
        try await getBasicUserInfo(identity: CollectionAccountIdentity(party: party))
    }
}

/// Supports both the shared BooleanResult schema and the literal boolean response description.
internal struct CollectionActiveResult: Decodable, Sendable {
    let result: Bool
    enum CodingKeys: String, CodingKey { case result }
    init(from decoder: any Decoder) throws {
        if let literal = try? decoder.singleValueContainer().decode(Bool.self) { result = literal }
        else { result = try decoder.container(keyedBy: CodingKeys.self).decode(Bool.self, forKey: .result) }
    }
}
