import Foundation
import MoMoCore
import MoMoDisbursements

/// Remittance credentials and token are isolated from Collections/Disbursements.
public struct MoMoRemittanceClient: Sendable {
    let client: MoMoAPIClient
    let tokenProvider: MoMoTokenProvider
    public init(credentials: MoMoCredentials, environment: MoMoEnvironment) {
        let client = MoMoAPIClient(environment: environment, subscriptionKey: credentials.subscriptionKey)
        self.init(client: client, tokenProvider: MoMoTokenProvider(apiUser: credentials.apiUser, apiKey: credentials.apiKey, tokenPath: "/remittance/token/", client: client))
    }
    public init(credentials: MoMoCredentials, environment: MoMoEnvironment, transport: any MoMoHTTPTransport, retryPolicy: MoMoRetryPolicy = .default) {
        let client = MoMoAPIClient(environment: environment, subscriptionKey: credentials.subscriptionKey, transport: transport, retryPolicy: retryPolicy)
        self.init(client: client, tokenProvider: MoMoTokenProvider(apiUser: credentials.apiUser, apiKey: credentials.apiKey, tokenPath: "/remittance/token/", client: client))
    }
    public init(client: MoMoAPIClient, tokenProvider: MoMoTokenProvider) { self.client = client; self.tokenProvider = tokenProvider }

    public func transfer(payload: RemittanceTransferRequest, referenceId: UUID = UUID(), callbackURL: String? = nil) async throws -> String {
        try MoMoValidation.amount(payload.amount)
        try RemittanceValidation.currency(payload.currency)
        try MoMoValidation.callbackURL(callbackURL)
        try RemittanceValidation.party(payload.payee)
        
        let id = referenceId.uuidString.lowercased()
        try MoMoValidation.referenceId(id)
        var headers = ["X-Reference-Id": id]
        if let callbackURL { headers["X-Callback-Url"] = callbackURL }
        let endpoint = RemittanceEndpoint(path: "/remittance/v1_0/transfer", method: .post, additionalHeaders: headers, data: try JSONEncoder().encode(payload))
        do { try await client.executeAuthenticated(endpoint, tokenProvider: tokenProvider) }
        catch { throw MoMoError.transactionFailure(referenceId: id, underlying: error) }
        return id
    }
    public func getTransferStatus(referenceId: String) async throws -> RemittanceTransferStatus {
        try MoMoValidation.referenceId(referenceId)
        return try await client.executeAuthenticated(RemittanceEndpoint(path: "/remittance/v1_0/transfer/\(MoMoPath.segment(referenceId))"), responseType: RemittanceTransferStatus.self, tokenProvider: tokenProvider)
    }
    public func transferAndWait(payload: RemittanceTransferRequest, referenceId: UUID = UUID(), callbackURL: String? = nil, policy: MoMoPollingPolicy = MoMoPollingPolicy()) async throws -> RemittanceTransferStatus {
        try policy.validate()
        let id = try await transfer(payload: payload, referenceId: referenceId, callbackURL: callbackURL)
        return try await MoMoPoller.poll(referenceId: id, policy: policy, operation: { try await getTransferStatus(referenceId: id) }, isComplete: { $0.status?.isTerminal == true })
    }

    public func cashTransfer(payload: CashTransferRequest, referenceId: UUID = UUID(), callbackURL: String? = nil) async throws -> String {
        try MoMoValidation.amount(payload.amount)
        try RemittanceValidation.currency(payload.currency)
        try MoMoValidation.callbackURL(callbackURL)
        try RemittanceValidation.party(payload.payee)
        if let originalAmount = payload.originalAmount { try MoMoValidation.amount(originalAmount) }; if let originalCurrency = payload.originalCurrency { try RemittanceValidation.currency(originalCurrency) }
        let id = referenceId.uuidString.lowercased()
        try MoMoValidation.referenceId(id)
        var headers = ["X-Reference-Id": id]
        if let callbackURL { headers["X-Callback-Url"] = callbackURL }
        let endpoint = RemittanceEndpoint(path: "/remittance/v2_0/cashtransfer", method: .post, additionalHeaders: headers, data: try JSONEncoder().encode(payload))
        do { try await client.executeAuthenticated(endpoint, tokenProvider: tokenProvider) }
        catch { throw MoMoError.transactionFailure(referenceId: id, underlying: error) }
        return id
    }
    public func getCashTransferStatus(referenceId: String) async throws -> CashTransferStatus {
        try MoMoValidation.referenceId(referenceId)
        return try await client.executeAuthenticated(RemittanceEndpoint(path: "/remittance/v2_0/cashtransfer/\(MoMoPath.segment(referenceId))"), responseType: CashTransferStatus.self, tokenProvider: tokenProvider)
    }
    public func cashTransferAndWait(payload: CashTransferRequest, referenceId: UUID = UUID(), callbackURL: String? = nil, policy: MoMoPollingPolicy = MoMoPollingPolicy()) async throws -> CashTransferStatus {
        try policy.validate()
        let id = try await cashTransfer(payload: payload, referenceId: referenceId, callbackURL: callbackURL)
        return try await MoMoPoller.poll(referenceId: id, policy: policy, operation: { try await getCashTransferStatus(referenceId: id) }, isComplete: { $0.status?.isTerminal == true })
    }

    public func getAccountBalance(currency: String? = nil) async throws -> AccountBalance {
        if let currency { try RemittanceValidation.currency(currency) }
        return try await client.executeAuthenticated(RemittanceEndpoint(path: "/remittance/v1_0/account/balance" + (currency.map { "/" + MoMoPath.segment($0) } ?? "")), responseType: AccountBalance.self, tokenProvider: tokenProvider)
    }
    public func isAccountHolderActive(party: Party) async throws -> Bool {
        guard party.partyIdType != .partyCode else { throw MoMoError.invalidConfiguration("Active-account lookup supports MSISDN or email") }
        try RemittanceValidation.party(party)
        let path = "/remittance/v1_0/accountholder/\(party.partyIdType.rawValue.lowercased())/\(MoMoPath.segment(party.partyId))/active"
        do { return try await client.executeAuthenticated(RemittanceEndpoint(path: path), responseType: Bool.self, tokenProvider: tokenProvider) }
        catch let error as MoMoError where error.statusCode == 404 { return false }
    }
    /// The verified Remittance basic-user-info route accepts MSISDN only.
    public func getBasicUserInfo(msisdn: String) async throws -> RemittanceBasicUserInfo {
        try RemittanceValidation.party(Party(partyIdType: .msisdn, partyId: msisdn))
        return try await client.executeAuthenticated(RemittanceEndpoint(path: "/remittance/v1_0/accountholder/msisdn/\(MoMoPath.segment(msisdn))/basicuserinfo"), responseType: RemittanceBasicUserInfo.self, tokenProvider: tokenProvider)
    }
}
struct RemittanceEndpoint: MoMoEndpoint {
    let path: String
    var method: HTTPMethod = .get
    var additionalHeaders: [String: String]? = nil
    var data: Data? = nil
    func body() throws -> Data? { data }
}
enum RemittanceValidation {
    static func currency(_ currency: String) throws {
        guard currency.range(of: "^[A-Z]{3}$", options: .regularExpression) != nil else { throw MoMoError.invalidConfiguration("Currency must be a three-letter uppercase code") }
    }
    static func party(_ party: Party) throws {
        guard !party.partyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw MoMoError.invalidConfiguration("Payee identifier is empty") }
    }
}
public struct RemittanceBasicUserInfo: Codable, Sendable, Equatable {
    public let givenName: String?
    public let familyName: String?
    public let birthdate: String?
    public let locale: String?
    public let status: String?
    enum CodingKeys: String, CodingKey { case givenName = "given_name", familyName = "family_name", birthdate, locale, status }
}
