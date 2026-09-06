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
    
    var path: String {
        switch self {
        case .createUser:
            return "/v1_0/apiuser"
        case .createKey(let referenceId):
            return "/v1_0/apiuser/\(referenceId)/apikey"
        }
    }
    
    var method: HTTPMethod {
        return .post
    }
    
    var additionalHeaders: [String : String]? {
        switch self {
        case .createUser(let referenceId, _):
            return ["X-Reference-Id": referenceId]
        case .createKey:
            return nil // Inherits the Ocp-Apim-Subscription-Key automatically from the client
        }
    }
    
    func body() throws -> Data? {
        switch self {
        case .createUser(_, let callbackHost):
            let payload = APIUserPayload(providerCallbackHost: callbackHost)
            return try JSONEncoder().encode(payload)
        case .createKey:
            return nil
        }
    }
}
/// A utility exclusively used in the Sandbox environment to provision testing credentials.
public struct MoMoSandboxProvisioner {
    private let client: MoMoAPIClient
    
    public init(client: MoMoAPIClient) {
        self.client = client
    }
    
    /// Generates a new API User (UUID) and fetches its corresponding API Key.
    /// - Parameter callbackHost: The domain registered for your webhooks (e.g., "webhook.site").
    /// - Returns: A tuple containing the newly generated `apiUser` and `apiKey`.
    public func createSandboxCredentials(
        callbackHost: String = "localhost"
    ) async throws -> (apiUser: String, apiKey: String) {
        
        // 1. Safety Check: Ensure this is never run against a production URL
        guard case .sandbox = client.environment else {
            throw MoMoError.unauthorized(message: "Provisioning is only allowed in the Sandbox environment.")
        }
        
        // The UUID becomes the API User ID
        let referenceId = UUID().uuidString
        
        // 2. Create the API User
        // Expects a 201 Created. No response body to decode.
        let userEndpoint = SandboxEndpoint.createUser(referenceId: referenceId, callbackHost: callbackHost)
        try await client.execute(userEndpoint, bearerToken: nil)
        
        // 3. Generate the API Key
        // Expects a 201 Created with a JSON body containing the API key.
        let keyEndpoint = SandboxEndpoint.createKey(referenceId: referenceId)
        let response = try await client.execute(keyEndpoint, responseType: APIKeyResponse.self, bearerToken: nil)
        
        return (apiUser: referenceId, apiKey: response.apiKey)
    }
}
