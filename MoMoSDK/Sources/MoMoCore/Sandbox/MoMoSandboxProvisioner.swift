//
//  MoMoSandboxProvisioner.swift
//  MoMoSDK
//
//  Created by kobby on 06/09/2026.
//
import Foundation

// MARK: - Payloads & Responses

private struct APIUserPayload: Codable {
    let providerCallbackHost: String
}

private struct APIKeyResponse: Codable {
    let apiKey: String
}

// MARK: - Endpoints

private enum SandboxEndpoint: MoMoEndpoint {
    case createUser(referenceId: String, callbackHost: String)
    case createKey(referenceId: String)
    case getUser(referenceId: String)
    
    var path: String {
        switch self {
        case .createUser:
            return "/v1_0/apiuser"
        case .createKey(let referenceId):
            return "/v1_0/apiuser/\(MoMoPath.segment(referenceId))/apikey"
        case .getUser(let id): return "/v1_0/apiuser/\(MoMoPath.segment(id))"
        }
    }
    
    var method: HTTPMethod {
        if case .getUser = self { return .get }; return .post
    }
    
    var additionalHeaders: [String : String]? {
        switch self {
        case .createUser(let referenceId, _):
            return ["X-Reference-Id": referenceId]
        case .createKey, .getUser:
            return nil // Inherits the Ocp-Apim-Subscription-Key automatically from the client
        }
    }
    
    func body() throws -> Data? {
        switch self {
        case .createUser(_, let callbackHost):
            let payload = APIUserPayload(providerCallbackHost: callbackHost)
            return try JSONEncoder().encode(payload)
        case .createKey, .getUser:
            return nil
        }
    }
}
/// A utility exclusively used in the Sandbox environment to provision testing credentials.
public struct MoMoSandboxUser: Decodable, Sendable {
    public let providerCallbackHost: String?
    public let targetEnvironment: String?
}

public struct MoMoSandboxProvisioner: Sendable {
    private let client: MoMoAPIClient
    
    public init(subscriptionKey: String) {
        let client = MoMoAPIClient(environment: .sandbox, subscriptionKey: subscriptionKey)
        self.init(client: client)
    }
    
    public init(subscriptionKey: String, transport: any MoMoHTTPTransport) {
        client = MoMoAPIClient(environment: .sandbox, subscriptionKey: subscriptionKey, transport: transport)
    }

    public init(client: MoMoAPIClient) {
        self.client = client
    }
    
    public func createUser(referenceId: String = UUID().uuidString.lowercased(), callbackHost: String = "webhook.site") async throws -> String {
        try validate(referenceId)
        guard let url = URLComponents(string: "https://" + callbackHost), url.host == callbackHost, url.path.isEmpty, url.query == nil, url.fragment == nil, url.user == nil, url.port == nil else { throw MoMoError.invalidConfiguration("Callback host must be a hostname") }
        try await client.execute(SandboxEndpoint.createUser(referenceId: referenceId, callbackHost: callbackHost))
        return referenceId
    }
    public func createKey(referenceId: String) async throws -> String {
        try validate(referenceId)
        return try await client.execute(SandboxEndpoint.createKey(referenceId: referenceId), responseType: APIKeyResponse.self).apiKey
    }
    public func getUser(referenceId: String) async throws -> MoMoSandboxUser {
        try validate(referenceId)
        return try await client.execute(SandboxEndpoint.getUser(referenceId: referenceId), responseType: MoMoSandboxUser.self)
    }
    private func validate(_ referenceId: String) throws {
        guard case .sandbox = client.environment else { throw MoMoError.invalidConfiguration("Provisioning is sandbox only") }
        try MoMoValidation.referenceId(referenceId)
        guard referenceId.split(separator: "-")[2].first == "4" else { throw MoMoError.invalidConfiguration("Sandbox user reference must be UUID version 4") }
    }

    /// Generates a new API User (UUID) and fetches its corresponding API Key.
    /// - Parameter callbackHost: The domain registered for your webhooks (e.g., "webhook.site").
    /// - Returns: A tuple containing the newly generated `apiUser` and `apiKey`.
    public func createSandboxCredentials(
        callbackHost: String = "webhook.site"
    ) async throws -> (apiUser: String, apiKey: String) {
        
        let referenceId = try await createUser(callbackHost: callbackHost)
        return (referenceId, try await createKey(referenceId: referenceId))
    }
}
