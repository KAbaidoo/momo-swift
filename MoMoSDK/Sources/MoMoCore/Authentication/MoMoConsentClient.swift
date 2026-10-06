import Foundation

public enum MoMoProduct: String, Sendable, CaseIterable { case collection, disbursement, remittance }
public enum MoMoConsentAccessType: String, Sendable { case online, offline }
public struct MoMoConsentAuthorization: Decodable, Sendable {
    public let authRequestId: String
    public let interval: Double
    public let expiresIn: Double
    enum CodingKeys: String, CodingKey { case authRequestId = "auth_req_id", interval, expiresIn = "expires_in" }
}
public struct MoMoConsentToken: Decodable, Sendable {
    public let accessToken: String
    public let tokenType: String
    public let expiresIn: Double
    public let scope: String?
    public let refreshToken: String?
    public let refreshTokenExpiredIn: Int?
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token", tokenType = "token_type", expiresIn = "expires_in", scope
        case refreshToken = "refresh_token", refreshTokenExpiredIn = "refresh_token_expired_in"
    }
}
/// Supports the textual response property and the structured address component published by MTN.
public struct MoMoConsentAddress: Decodable, Sendable, Equatable {
    public let formatted: String?
    public let streetAddress: String?
    public let locality: String?
    public let region: String?
    public let postalCode: String?
    public let country: String?
    enum CodingKeys: String, CodingKey { case formatted, locality, region, country; case streetAddress = "street_address", postalCode = "postal_code" }
    public init(from decoder: any Decoder) throws {
        if let text = try? decoder.singleValueContainer().decode(String.self) {
            formatted = text; streetAddress = nil; locality = nil; region = nil; postalCode = nil; country = nil
        } else {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            formatted = try container.decodeIfPresent(String.self, forKey: .formatted)
            streetAddress = try container.decodeIfPresent(String.self, forKey: .streetAddress)
            locality = try container.decodeIfPresent(String.self, forKey: .locality)
            region = try container.decodeIfPresent(String.self, forKey: .region)
            postalCode = try container.decodeIfPresent(String.self, forKey: .postalCode)
            country = try container.decodeIfPresent(String.self, forKey: .country)
        }
    }
}
/// Fields are optional because availability depends on requested scopes and operator entitlement.
public struct MoMoConsentUserInfo: Decodable, Sendable {
    public let sub: String?
    public let name: String?
    public let givenName: String?
    public let familyName: String?
    public let middleName: String?
    public let email: String?
    public let emailVerified: Bool?
    public let gender: String?
    public let locale: String?
    public let phoneNumber: String?
    public let phoneNumberVerified: Bool?
    public let address: MoMoConsentAddress?
    public let updatedAt: Double?
    public let status: String?
    public let birthdate: String?
    public let creditScore: String?
    public let active: Bool?
    public let countryOfBirth: String?
    public let regionOfBirth: String?
    public let cityOfBirth: String?
    public let occupation: String?
    public let employerName: String?
    public let identificationType: String?
    public let identificationValue: String?
    enum CodingKeys: String, CodingKey {
        case sub, name, email, gender, locale, address, status, birthdate, active, occupation
        case givenName = "given_name", familyName = "family_name", middleName = "middle_name", emailVerified = "email_verified"
        case phoneNumber = "phone_number", phoneNumberVerified = "phone_number_verified", updatedAt = "updated_at", creditScore = "credit_score"
        case countryOfBirth = "country_of_birth", regionOfBirth = "region_of_birth", cityOfBirth = "city_of_birth", employerName = "employer_name"
        case identificationType = "identification_type", identificationValue = "identification_value"
    }
}
private struct ConsentEndpoint: MoMoEndpoint {
    let path: String
    let method: HTTPMethod
    let additionalHeaders: [String: String]?
    var fields: [String: String]? = nil
    func body() throws -> Data? {
        fields.map { fields in
            Data(fields.sorted(by: { $0.key < $1.key }).map { "\(MoMoPath.segment($0.key))=\(MoMoPath.segment($0.value))" }.joined(separator: "&").utf8)
        }
    }
}
/// Consumer consent tokens are kept separate from merchant product tokens. CIBA authorization uses
/// a caller-supplied bearer for Collections and Basic API credentials for payout products, matching
/// the current exports. Obtain operator clarification before production deployment.
public struct MoMoConsentClient: Sendable {
    private let client: MoMoAPIClient
    private let credentials: MoMoCredentials
    public let product: MoMoProduct
    public init(credentials: MoMoCredentials, environment: MoMoEnvironment = .sandbox, product: MoMoProduct, transport: any MoMoHTTPTransport = MoMoURLSessionTransport(), retryPolicy: MoMoRetryPolicy = .default) {
        self.credentials = credentials; self.product = product
        client = MoMoAPIClient(environment: environment, subscriptionKey: credentials.subscriptionKey, transport: transport, retryPolicy: retryPolicy)
    }
    private var basic: String { "Basic " + Data("\(credentials.apiUser):\(credentials.apiKey)".utf8).base64EncodedString() }
    /// Additional consent fields are published for Disbursements and Remittance only.
    /// MTN's export does not define units for `consentValidIn` or accepted `scopeInstruction` values.
    public func authorize(loginHint: String, scopes: [String], accessType: MoMoConsentAccessType = .online, callbackURL: String? = nil, bearerToken: String? = nil, consentValidIn: Int? = nil, clientNotificationToken: String? = nil, scopeInstruction: String? = nil) async throws -> MoMoConsentAuthorization {
        guard !loginHint.isEmpty, !scopes.isEmpty, scopes.allSatisfy({ !$0.isEmpty && !$0.contains(where: { $0.isWhitespace }) }) else { throw MoMoError.invalidConfiguration("Consent requires a login hint and nonempty scope names") }
        guard product != .collection || (consentValidIn == nil && clientNotificationToken == nil && scopeInstruction == nil) else {
            throw MoMoError.invalidConfiguration("Additional consent fields are only documented for Disbursements and Remittance")
        }
        if let consentValidIn, consentValidIn <= 0 { throw MoMoError.invalidConfiguration("Consent validity must be positive") }
        try MoMoValidation.callbackURL(callbackURL)
        var headers = ["Content-Type": "application/x-www-form-urlencoded"]
        if product == .collection {
            guard let bearerToken, !bearerToken.isEmpty else { throw MoMoError.invalidConfiguration("Collections authorization requires an explicit bearer token") }
            headers["Authorization"] = "Bearer \(bearerToken)"
        } else { headers["Authorization"] = basic }
        headers["X-Callback-Url"] = callbackURL
        var fields = ["login_hint": loginHint, "scope": scopes.joined(separator: " "), "access_type": accessType.rawValue]
        fields["consent_valid_in"] = consentValidIn.map(String.init)
        fields["client_notification_token"] = clientNotificationToken
        fields["scope_instruction"] = scopeInstruction
        return try await client.execute(ConsentEndpoint(path: "/\(product.rawValue)/v1_0/bc-authorize", method: .post, additionalHeaders: headers, fields: fields), responseType: MoMoConsentAuthorization.self)
    }
    public func exchange(authRequestId: String) async throws -> MoMoConsentToken {
        guard !authRequestId.isEmpty else { throw MoMoError.invalidConfiguration("Authorization request ID is required") }
        return try await token(fields: ["grant_type": "urn:openid:params:grant-type:ciba", "auth_req_id": authRequestId])
    }
    public func refresh(refreshToken: String) async throws -> MoMoConsentToken {
        guard !refreshToken.isEmpty else { throw MoMoError.invalidConfiguration("Refresh token is required") }
        return try await token(fields: ["grant_type": "refresh_token", "refresh_token": refreshToken])
    }
    private func token(fields: [String: String]) async throws -> MoMoConsentToken {
        try await client.execute(ConsentEndpoint(path: "/\(product.rawValue)/oauth2/token/", method: .post, additionalHeaders: ["Authorization": basic, "Content-Type": "application/x-www-form-urlencoded"], fields: fields), responseType: MoMoConsentToken.self)
    }
    public func userInfo(accessToken: String) async throws -> MoMoConsentUserInfo {
        guard !accessToken.isEmpty else { throw MoMoError.invalidConfiguration("Consumer access token is required") }
        return try await client.execute(ConsentEndpoint(path: "/\(product.rawValue)/oauth2/v1_0/userinfo", method: .get, additionalHeaders: nil), responseType: MoMoConsentUserInfo.self, bearerToken: accessToken)
    }
}
