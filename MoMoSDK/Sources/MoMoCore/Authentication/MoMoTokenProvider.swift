//
//  MoMoTokenProvider.swift
//  MoMoSDK
//
//  Created by kobby on 27/08/2026.
//

import Foundation



// MARK: - Internal Token Models
struct TokenResponse: Decodable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}

struct TokenEndpoint: MoMoEndpoint {
    let path: String
    let basicAuthToken: String
    
    var method: HTTPMethod {
        return .post
    }
    
    var additionalHeaders: [String : String]? {
        ["Authorization":"Basic \(basicAuthToken)",
         // The token endpoint requires an empty body or a specific content type
         "Content-Length":"0"
        ]
    }
}

public actor MoMoTokenProvider {
    private let apiUser: String
    private let apiKey: String
    private let tokenPath: String
    private let client: MoMoAPIClient
    
    // State
    private var currentToken: String?
    private var expirationDate: Date?
    
    // Task reference to prevent duplicate concurrent network calls
    private var refreshTask: Task<String, Error>?
    
    public init(
        apiUser: String,
        apiKey: String,
        tokenPath: String,
        client: MoMoAPIClient
    ) {
        self.apiKey = apiKey
        self.tokenPath = tokenPath
        self.apiUser = apiUser
        self.client = client
    }
    
    
    /// Returns a valid bearer token, if current token is expired, it automatically fetches a new one.
    public func getValidToken() async throws -> String {
        // 1. Return cached token if it's still valid (with a 60-second safety buffer)
        if let token = currentToken,
           let exp = expirationDate,
           exp > Date(timeIntervalSinceNow: 60) {
            return token
        }
        
        // 2. If a fetch is already in progress, just await its result
        if let existingTask = refreshTask {
            return try await existingTask.value
        }
        
        // 3. Otherwise, create a new task to fetch the token
        let task = Task {
            defer { self.refreshTask = nil }
            return try await fetchNewToken()
        }
        
        self.refreshTask = task
        return try await task.value
    }
    
    private func fetchNewToken() async throws -> String {
        // Create the Base64 Basic Auth string expected by the API
        let credentials = "\(apiUser):\(apiKey)"
        
        guard let credentialsData = credentials.data(using: .utf8) else {
            throw MoMoError.unauthorized(message: "Failed to encode credentials")
        }
        let base64Credentials = credentialsData.base64EncodedString()
        
        let endpoint = TokenEndpoint(path: tokenPath, basicAuthToken: base64Credentials)
        
        let response = try await client.execute( endpoint, responseType: TokenResponse.self, bearerToken: nil)
        
        self.currentToken = response.accessToken
        
        // Calculate exact expiration date
        self.expirationDate = Date().addingTimeInterval(TimeInterval(response.expiresIn))
        
        return response.accessToken
    }
    
}
