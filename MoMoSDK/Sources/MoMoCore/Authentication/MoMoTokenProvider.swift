//
//  MoMoTokenProvider.swift
//  MoMoSDK
//
//  Created by kobby on 27/08/2026.
//

import Foundation



// MARK: - Internal Token Models
struct TokenResponse: Decodable, Sendable {
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
    private let now: @Sendable () -> Date
    
    // State
    private var currentToken: String?
    private var expirationDate: Date?
    
    // Task reference to prevent duplicate concurrent network calls
    private var refreshTask: Task<String, Error>?
    private var refreshId: UUID?
    
    public init(
        apiUser: String,
        apiKey: String,
        tokenPath: String,
        client: MoMoAPIClient,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.apiKey = apiKey
        self.tokenPath = tokenPath
        self.apiUser = apiUser
        self.client = client
        self.now = now
    }
    
    
    /// Returns a valid bearer token, if current token is expired, it automatically fetches a new one.
    public func getValidToken() async throws -> String {
        try Task.checkCancellation()
        // 1. Return cached token if it's still valid (with a 60-second safety buffer)
        if let token = currentToken,
           let exp = expirationDate,
           exp > now() {
            return token
        }
        
        // 2. If a fetch is already in progress, just await its result
        if let existingTask = refreshTask {
            let value = try await existingTask.value
            try Task.checkCancellation()
            return value
        }
        
        // 3. Otherwise, create a new task to fetch the token
        let id = UUID()
        let task = Task {
            defer {
                if self.refreshId == id { self.refreshTask = nil; self.refreshId = nil }
            }
            return try await fetchNewToken()
        }
        self.refreshId = id
        self.refreshTask = task
        let value = try await task.value
        try Task.checkCancellation()
        return value
    }
    
    public func invalidate(token: String? = nil) {
        if token == nil || token == currentToken {
            currentToken = nil; expirationDate = nil
            if token == nil { refreshTask?.cancel(); refreshTask = nil; refreshId = nil }
        }
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
        
        try Task.checkCancellation()
        self.currentToken = response.accessToken
        
        // Calculate exact expiration date
        guard !response.accessToken.isEmpty, response.expiresIn > 0 else { throw MoMoError.invalidConfiguration("Invalid token response") }
        self.expirationDate = now().addingTimeInterval(max(0, Double(response.expiresIn) - min(60, Double(response.expiresIn) * 0.1)))
        
        return response.accessToken
    }
    
}
