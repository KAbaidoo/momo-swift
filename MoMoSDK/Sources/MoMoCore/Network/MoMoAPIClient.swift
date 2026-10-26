import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public actor MoMoAPIClient {
    public let environment: MoMoEnvironment
    public let subscriptionKey: String
    private let transport: any MoMoHTTPTransport
    private let retryPolicy: MoMoRetryPolicy

    public init(environment: MoMoEnvironment, subscriptionKey: String, urlSession: URLSession = .shared) {
        self.environment = environment
        self.subscriptionKey = subscriptionKey
        self.transport = MoMoURLSessionTransport(session: urlSession)
        self.retryPolicy = .default
    }
    public init(environment: MoMoEnvironment, subscriptionKey: String, transport: any MoMoHTTPTransport, retryPolicy: MoMoRetryPolicy = .default) {
        self.environment = environment
        self.subscriptionKey = subscriptionKey
        self.transport = transport
        self.retryPolicy = retryPolicy
    }

    public func execute<T: Decodable>(_ endpoint: any MoMoEndpoint, responseType: T.Type, bearerToken: String? = nil) async throws -> T {
        let response = try await performRequest(endpoint, bearerToken: bearerToken)
        guard !response.0.isEmpty else { throw MoMoError.emptyResponse }
        do { return try JSONDecoder().decode(T.self, from: response.0) }
        catch let error as DecodingError { throw MoMoError.decodingFailed(error) }
    }

    @discardableResult
    public func execute(_ endpoint: any MoMoEndpoint, bearerToken: String? = nil) async throws -> HTTPURLResponse {
        try await performRequest(endpoint, bearerToken: bearerToken).1
    }

    /// Recover an expired product token once for reads. Writes are never replayed.
    public func executeAuthenticated<T: Decodable & Sendable>(_ endpoint: any MoMoEndpoint, responseType: T.Type, tokenProvider: MoMoTokenProvider) async throws -> T {
        let token = try await tokenProvider.getValidToken()
        do { return try await execute(endpoint, responseType: responseType, bearerToken: token) }
        catch MoMoError.httpError(let error) where error.statusCode == 401 && endpoint.method == .get {
            await tokenProvider.invalidate(token: token)
            let refreshed = try await tokenProvider.getValidToken()
            return try await execute(endpoint, responseType: responseType, bearerToken: refreshed)
        }
    }

    @discardableResult
    public func executeAuthenticated(_ endpoint: any MoMoEndpoint, tokenProvider: MoMoTokenProvider) async throws -> HTTPURLResponse {
        let token = try await tokenProvider.getValidToken()
        do { return try await execute(endpoint, bearerToken: token) }
        catch MoMoError.httpError(let error) where error.statusCode == 401 && endpoint.method == .get {
            await tokenProvider.invalidate(token: token)
            return try await execute(endpoint, bearerToken: try await tokenProvider.getValidToken())
        }
    }

    /// Executes one financial submission while preserving whether the request reached the transport boundary.
    /// Errors before the transport invocation are reported as known pre-submission failures; errors after it
    /// are reported as uncertain transaction failures. This method never retries a submission.
    @discardableResult
    public func executeAuthenticatedSubmission(_ endpoint: any MoMoEndpoint, referenceId: String, tokenProvider: MoMoTokenProvider) async throws -> HTTPURLResponse {
        guard endpoint.method != .get else {
            throw MoMoError.preSubmissionFailure(
                referenceId: referenceId,
                underlying: MoMoError.invalidConfiguration("Authenticated submission requires a non-GET endpoint")
            )
        }

        let token: String
        do { token = try await tokenProvider.getValidToken() }
        catch { throw MoMoError.preSubmissionFailure(referenceId: referenceId, underlying: error) }

        return try await performRequest(endpoint, bearerToken: token, submissionReferenceId: referenceId).1
    }

    private func performRequest(_ endpoint: any MoMoEndpoint, bearerToken: String?, submissionReferenceId: String? = nil) async throws -> (Data, HTTPURLResponse) {
        var didDispatch = false
        do {
            try Task.checkCancellation()
            guard var components = URLComponents(url: environment.baseURL, resolvingAgainstBaseURL: false),
                  components.scheme?.lowercased() == "https", components.host?.isEmpty == false,
                  components.user == nil, components.password == nil, components.query == nil, components.fragment == nil,
                  endpoint.path.hasPrefix("/"), !endpoint.path.hasPrefix("//"),
                  !endpoint.path.contains("?"), !endpoint.path.contains("#"), !endpoint.path.contains("\\"),
                  !endpoint.path.split(separator: "/").contains(where: { $0 == "." || $0 == ".." }) else { throw MoMoError.invalidURL }
            // All dynamic components are encoded by endpoint builders. Validate existing percent escapes.
            let path = components.percentEncodedPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let combined = (path.isEmpty ? "" : "/" + path) + endpoint.path
            let permitted = CharacterSet.urlPathAllowed.union(CharacterSet(charactersIn: "%"))
            guard combined.unicodeScalars.allSatisfy({ permitted.contains($0) }), combined.removingPercentEncoding != nil else { throw MoMoError.invalidURL }
            components.percentEncodedPath = combined
            guard let url = components.url else { throw MoMoError.invalidURL }
            for value in [subscriptionKey, environment.targetEnvironmentHeaderValue, bearerToken ?? ""] {
                guard !value.contains(where: { $0.isNewline || $0 == "\0" }) else { throw MoMoError.invalidConfiguration("Invalid authentication header") }
            }
            var request = URLRequest(url: url)
            request.httpMethod = endpoint.method.rawValue
            request.timeoutInterval = 60
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(subscriptionKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
            request.setValue(environment.targetEnvironmentHeaderValue, forHTTPHeaderField: "X-Target-Environment")
            if let bearerToken { request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization") }
            for (key, value) in endpoint.additionalHeaders ?? [:] {
                guard !key.contains(where: { $0.isNewline }), !value.contains(where: { $0.isNewline }) else { throw MoMoError.invalidConfiguration("Invalid header") }
                request.setValue(value, forHTTPHeaderField: key)
            }
            request.httpBody = try endpoint.body()
            let attempts = endpoint.method == .get ? retryPolicy.maxAttempts : 1
            for attempt in 0..<attempts {
                try Task.checkCancellation()
                do {
                    // No suspension occurs between this marker and the transport invocation. Failures after
                    // this boundary may have reached the payment service, even when the transport throws.
                    if submissionReferenceId != nil { didDispatch = true }
                    let (data, response) = try await transport.data(for: request)
                    try Task.checkCancellation()
                    if (200...299).contains(response.statusCode) { return (data, response) }
                    let error = MoMoHTTPError(response: response, data: data)
                    if attempt + 1 < attempts && [408, 429, 500, 502, 503, 504].contains(response.statusCode) {
                        let requested = retryAfterSeconds(response.value(forHTTPHeaderField: "Retry-After"))
                        // A server's minimum wait must not be shortened by our retry budget.
                        if let requested, requested > retryPolicy.maximumDelay { throw MoMoError.httpError(error) }
                        try await delay(attempt: attempt, retryAfter: requested)
                        continue
                    }
                    throw MoMoError.httpError(error)
                } catch let error as URLError {
                    if error.code == .cancelled { throw CancellationError() }
                    guard attempt + 1 < attempts, [.timedOut, .networkConnectionLost, .cannotConnectToHost, .notConnectedToInternet, .dnsLookupFailed].contains(error.code) else { throw MoMoError.networkFailure(error) }
                    try await delay(attempt: attempt, retryAfter: nil)
                }
            }
            throw MoMoError.invalidConfiguration("Retry policy exhausted")
        } catch {
            guard let submissionReferenceId else { throw error }
            if didDispatch {
                throw MoMoError.transactionFailure(referenceId: submissionReferenceId, underlying: error)
            }
            throw MoMoError.preSubmissionFailure(referenceId: submissionReferenceId, underlying: error)
        }
    }
    private func delay(attempt: Int, retryAfter: Double?) async throws {
        var seconds = retryPolicy.initialDelay * pow(2, Double(attempt))
        if let retryAfter { seconds = max(seconds, retryAfter) }
        try await Task.sleep(nanoseconds: UInt64(min(seconds, retryPolicy.maximumDelay) * 1_000_000_000))
    }
    private func retryAfterSeconds(_ value: String?) -> Double? {
        guard let value else { return nil }
        if let seconds = Double(value), seconds.isFinite { return max(0, seconds) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter.date(from: value).map { max(0, $0.timeIntervalSinceNow) }
    }
}
