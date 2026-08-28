//
//  MoMoAPIClient.swift
//  MoMoSDK
//
//  Created by kobby on 27/08/2026.
//

import Foundation

public actor MoMoAPIClient{
    public let environment: MoMoEnvironment
    public let subscriptionKey: String
    private let urlSession: URLSession
    
    public init(environment: MoMoEnvironment, subscriptionKey: String, urlSession: URLSession = .shared) {
        self.environment = environment
        self.subscriptionKey = subscriptionKey
        self.urlSession = urlSession
    }
    
    /// Executes a request expecting a decoded JSON response (e.g. GET requests or OAuth Token generation)
    public func execute<T: Decodable>(_ endpoint: MoMoEndpoint, responseType: T.Type, bearerToken: String? = nil) async throws -> T {
        let response = try await performRequest(endpoint, bearerToken: bearerToken)
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: response.data)
        } catch  let error as DecodingError {
            throw MoMoError.decodingFailed(error)
        }
    }
    
    /// Executes a request where we only care about the success status (e.g., POST async operations returning 202 Accepted)
    public func execute(_ endpoint: MoMoEndpoint, bearerToken: String? = nil) async throws -> HTTPURLResponse {
        return try await performRequest(endpoint, bearerToken: bearerToken).response
    }
    
    
    // MARK: - Private Core Logic
    
    private func performRequest(_ endpoint: MoMoEndpoint, bearerToken: String?) async throws -> (data: Data, response: HTTPURLResponse) {
        
        guard let url = URL(string: environment.baseURL.absoluteString + endpoint.path) else {
            throw MoMoError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(subscriptionKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        request.setValue(environment.targetEnvironmentHeaderValue, forHTTPHeaderField: "X-Target-Environment")
        
        if let token = bearerToken {
            let bearerToken = "Bearer \(token)"
            request.setValue(bearerToken, forHTTPHeaderField: "Authorization")
        }
        
        endpoint.additionalHeaders?.forEach { (key, value) in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        request.httpBody = try endpoint.body()
        
        let (data, response): (Data, URLResponse)
        
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch let error as URLError {
            throw MoMoError.networkFailure(error)
        } catch {
            throw error
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MoMoError.unexpectedResponse
        }
        
        try validate(httpResponse: httpResponse, data: data)
                
        return (data, httpResponse)
    }
    
    private func validate(httpResponse: HTTPURLResponse, data: Data) throws {
            switch httpResponse.statusCode {
            case 200...299:
                return // Success cases (200 OK, 201 Created, 202 Accepted)
            case 401:
                throw MoMoError.unauthorized(message: String(data: data, encoding: .utf8) ?? "Unknown")
            case 404:
                throw MoMoError.resourceNotFound(message: String(data: data, encoding: .utf8) ?? "Unknown")
            case 409:
                throw MoMoError.conflict(message: String(data: data, encoding: .utf8) ?? "Duplicate request")
            case 500...599:
                throw MoMoError.serverError(statusCode: httpResponse.statusCode)
            default:
                throw MoMoError.unexpectedResponse
            }
        }
}
