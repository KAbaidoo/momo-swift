import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct MoMoAPIReason: Codable, Sendable, Equatable {
    public let code: String?
    public let message: String?
    public init(code: String? = nil, message: String? = nil) { self.code = code; self.message = message }
}
public struct MoMoHTTPError: Error, Sendable {
    public let statusCode: Int
    public let code: String?
    public let message: String?
    public let headers: [String: String]
    public init(statusCode: Int, code: String? = nil, message: String? = nil, headers: [String: String] = [:]) {
        self.statusCode = statusCode; self.code = code; self.message = message; self.headers = headers
    }
    init(response: HTTPURLResponse, data: Data) {
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        statusCode = response.statusCode
        code = object?["code"] as? String ?? object?["error"] as? String
        message = object?["message"] as? String ?? object?["error_description"] as? String
        // Retain operational metadata, never echo authentication or arbitrary response payloads.
        headers = ["Retry-After", "X-Request-Id", "X-Correlation-Id"].reduce(into: [:]) { result, key in
            if let value = response.value(forHTTPHeaderField: key) { result[key] = value }
        }
    }
}
public indirect enum MoMoError: Error, LocalizedError {
    case invalidURL, emptyResponse
    case invalidConfiguration(String)
    case networkFailure(URLError)
    case httpError(MoMoHTTPError)
    case pollingExhausted(referenceId: String)
    case transactionFailure(referenceId: String, underlying: any Error)
    case badRequest(message: String), unauthorized(message: String), conflict(message: String), resourceNotFound(message: String)
    case serverError(statusCode: Int)
    case decodingFailed(DecodingError)
    case unexpectedResponse(statusCode: Int, message: String)
    /// Cancellation of a financial operation stops waiting; it does not cancel settlement.
    public var isCancellation: Bool {
        switch self {
        case .transactionFailure(_, let error):
            return error is CancellationError || (error as? MoMoError)?.isCancellation == true
        default: return false
        }
    }
    public var referenceId: String? {
        switch self { case .pollingExhausted(let id), .transactionFailure(let id, _): return id; default: return nil }
    }
    public var statusCode: Int? {
        switch self {
        case .httpError(let error): return error.statusCode
        case .badRequest: return 400
        case .unauthorized: return 401
        case .conflict: return 409
        case .resourceNotFound: return 404
        case .serverError(let code), .unexpectedResponse(let code, _): return code
        case .transactionFailure(_, let error): return (error as? MoMoError)?.statusCode
        default: return nil
        }
    }
    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid or insecure URL"
        case .emptyResponse: return "Expected a response body"
        case .invalidConfiguration(let message): return message
        case .httpError(let error): return "HTTP \(error.statusCode)\(error.code.map { ": \($0)" } ?? "")"
        case .networkFailure(let error): return error.localizedDescription
        case .pollingExhausted(let id): return "Polling exhausted; reconcile transaction \(id)"
        case .transactionFailure(let id, _): return "Transaction outcome uncertain; reconcile \(id)"
        case .badRequest(let msg), .unauthorized(let msg), .conflict(let msg), .resourceNotFound(let msg): return msg
        case .serverError(let code): return "Server error \(code)"
        case .decodingFailed: return "Failed to decode response"
        case .unexpectedResponse(let code, let msg): return "Unexpected \(code): \(msg)"
        }
    }
}
