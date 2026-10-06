import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Injection boundary for networking. Implementations must not automatically replay writes.
public protocol MoMoHTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct MoMoURLSessionTransport: MoMoHTTPTransport {
    private let session: URLSession
    public init(session: URLSession = .shared) { self.session = session }
    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request, delegate: RedirectBlocker())
        guard let response = response as? HTTPURLResponse else {
            throw MoMoError.unexpectedResponse(statusCode: -1, message: "Non-HTTP response")
        }
        // Do not allow redirects to silently forward merchant credentials to another origin.
        guard response.url?.scheme == request.url?.scheme,
              response.url?.host == request.url?.host,
              response.url?.port == request.url?.port else { throw MoMoError.invalidURL }
        return (data, response)
    }
}

public enum MoMoPath {
    /// Encodes one opaque path parameter, including slashes and percent signs.
    public static func segment(_ value: String) -> String {
        if value == "." { return "%2E" }
        if value == ".." { return "%2E%2E" }
        return value.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")) ?? ""
    }
}

/// Retries are restricted to GET, and to transient transport/status failures.
public struct MoMoRetryPolicy: Sendable {
    public let maxAttempts: Int
    public let initialDelay: TimeInterval
    public let maximumDelay: TimeInterval
    public init(maxAttempts: Int = 3, initialDelay: TimeInterval = 0.5, maximumDelay: TimeInterval = 30) {
        self.maxAttempts = min(10, max(1, maxAttempts))
        self.initialDelay = initialDelay.isFinite ? min(86_400, max(0, initialDelay)) : 0.5
        self.maximumDelay = maximumDelay.isFinite ? min(86_400, max(0, maximumDelay)) : 30
    }
    public static let `default` = MoMoRetryPolicy()
    public static let none = MoMoRetryPolicy(maxAttempts: 1)
}

/// A redirect is returned as a 3xx response rather than forwarding a credentialed request.
private final class RedirectBlocker: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
