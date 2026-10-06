import Foundation
import MoMoCore

public struct DisbursementBasicUserInfo: Codable, Sendable, Equatable {
    public let givenName: String?
    public let familyName: String?
    public let birthdate: String?
    public let locale: String?
    public let gender: String?
    public let status: String?
    enum CodingKeys: String, CodingKey { case givenName = "given_name", familyName = "family_name", birthdate, locale, gender, status }
}
/// Identity casing for the basic-user-info contract differs from active-account lookup.
public struct DisbursementAccountIdentity: Sendable, Equatable {
    public enum Kind: String, Sendable { case msisdn = "MSISDN", email, alias, id }
    public let kind: Kind
    public let value: String
    public init(kind: Kind, value: String) { self.kind = kind; self.value = value }
    init(party: Party) throws {
        switch party.partyIdType {
        case .msisdn: self.init(kind: .msisdn, value: party.partyId)
        case .email: self.init(kind: .email, value: party.partyId)
        case .partyCode: throw MoMoError.invalidConfiguration("Party code is not supported by this account endpoint")
        }
    }
}
extension MoMoDisbursementClient {
    public func getAccountBalance(currency: String? = nil) async throws -> AccountBalance {
        if let currency { try PayoutValidation.money(amount: "1", currency: currency) }
        return try await client.executeAuthenticated(DisbursementAccountEndpoint.getBalance(currency: currency), responseType: AccountBalance.self, tokenProvider: tokenProvider)
    }
    public func isAccountHolderActive(party: Party) async throws -> Bool {
        try PayoutValidation.party(party)
        _ = try DisbursementAccountIdentity(party: party)
        do {
            return try await client.executeAuthenticated(DisbursementAccountEndpoint.validateAccountHolder(party: party), responseType: Bool.self, tokenProvider: tokenProvider)
        } catch let error as MoMoError where error.statusCode == 404 { return false }
    }
    public func getBasicUserInfo(party: Party) async throws -> DisbursementBasicUserInfo {
        try await getBasicUserInfo(identity: DisbursementAccountIdentity(party: party))
    }
    public func getBasicUserInfo(identity: DisbursementAccountIdentity) async throws -> DisbursementBasicUserInfo {
        guard !identity.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw MoMoError.invalidConfiguration("Account identifier is empty") }
        return try await client.executeAuthenticated(DisbursementAccountEndpoint.getBasicUserInfo(identity: identity), responseType: DisbursementBasicUserInfo.self, tokenProvider: tokenProvider)
    }
}
