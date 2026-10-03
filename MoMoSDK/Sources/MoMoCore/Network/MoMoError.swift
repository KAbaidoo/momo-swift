//
//  MoMoError.swift
//  MoMoSDK
//
//  Created by kobby on 26/08/2026.
//

import Foundation

public enum MoMoError: Error, LocalizedError {
    
    case invalidURL
    case networkFailure(URLError)
    case badRequest(message: String)        // 400: Invalid payload or headers
    case unauthorized(message: String)      //401: Token expires or invalid keys
    case conflict(message: String)          //409: Duplicate X-Reference-Id
    case resourceNotFound(message: String)  //404: Transaction ID not found
    case serverError(statusCode: Int)       //5xx: Gateway issues
    case decodingFailed(DecodingError)
    case unexpectedResponse(statusCode: Int, message: String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkFailure(let error):
            return error.localizedDescription
        case .unauthorized(message: let message):
            return "Authorization failed: \(message)"
        case .conflict(message: let message):
            return "Conflict: \(message) Likely duplicate Reference ID"
        case .badRequest(let msg):
            return "Bad Request: \(msg)"
        case .resourceNotFound(message: let message):
            return "Resource not found: \(message)"
        case .serverError(statusCode: let statusCode):
            return "Server error with status code: \(statusCode)"
        case .unexpectedResponse(let code, let msg):
            return "Unexpected \(code): \(msg)"
        case .decodingFailed(_):
            return "Failed to decode response"
        }
    }

}
