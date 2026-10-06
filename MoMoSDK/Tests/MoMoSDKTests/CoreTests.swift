import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import MoMoCore

private actor CoreMockTransport: MoMoHTTPTransport {
    struct Reply: Sendable { var status: Int; var body: String; var headers: [String: String] = [:] }
    private var replies: [Reply]
    private(set) var requests: [URLRequest] = []
    init(_ replies: [Reply]) { self.replies = replies }
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        guard !replies.isEmpty else { throw URLError(.badServerResponse) }
        let reply = replies.removeFirst()
        return (Data(reply.body.utf8), HTTPURLResponse(url: request.url!, statusCode: reply.status, httpVersion: nil, headerFields: reply.headers)!)
    }
}
private struct CoreEndpoint: MoMoEndpoint {
    var path: String = "/test"
    var method: HTTPMethod = .get
}
private struct CoreValue: Decodable, Sendable { let value: Int }

@Test func coreSafeReadRetryAndStructuredError() async throws {
    let transport = CoreMockTransport([.init(status: 503, body: "{}"), .init(status: 200, body: "{\"value\":7}")])
    let client = MoMoAPIClient(environment: .sandbox, subscriptionKey: "synthetic", transport: transport, retryPolicy: .init(initialDelay: 0))
    let value = try await client.execute(CoreEndpoint(), responseType: CoreValue.self)
    #expect(value.value == 7)
    #expect(await transport.requests.count == 2)
    let denied = CoreMockTransport([.init(status: 403, body: "{\"code\":\"NOT_ALLOWED\",\"message\":\"restricted\"}")])
    do { _ = try await MoMoAPIClient(environment: .sandbox, subscriptionKey: "s", transport: denied).execute(CoreEndpoint()) ; Issue.record("Expected error") }
    catch MoMoError.httpError(let error) { #expect(error.statusCode == 403); #expect(error.code == "NOT_ALLOWED"); #expect(error.message == "restricted") }
}
@Test func coreNeverReplaysWrite() async throws {
    let transport = CoreMockTransport([.init(status: 503, body: "{}"), .init(status: 202, body: "")])
    let client = MoMoAPIClient(environment: .sandbox, subscriptionKey: "s", transport: transport, retryPolicy: .init(initialDelay: 0))
    do { _ = try await client.execute(CoreEndpoint(method: .post)); Issue.record("Expected 503") }
    catch { #expect((error as? MoMoError)?.statusCode == 503) }
    #expect(await transport.requests.count == 1)
}
@Test func coreRejectsUnsafeURLsAndEncodesOpaqueIdentifiers() async throws {
    #expect(MoMoPath.segment("a/b?%") == "a%2Fb%3F%25")
    let transport = CoreMockTransport([])
    for endpoint in [CoreEndpoint(path: "//evil.example/path"), CoreEndpoint(path: "/../x"), CoreEndpoint(path: "/bad%escape")] {
        do { _ = try await MoMoAPIClient(environment: .sandbox, subscriptionKey: "s", transport: transport).execute(endpoint); Issue.record("Expected invalid URL") }
        catch MoMoError.invalidURL {}
    }
    do { _ = try await MoMoAPIClient(environment: .production(targetEnvironment: "operator", baseURL: URL(string: "http://example.test")!), subscriptionKey: "s", transport: transport).execute(CoreEndpoint()); Issue.record("Expected invalid URL") }
    catch MoMoError.invalidURL {}
    #expect(await transport.requests.isEmpty)
}
@Test func coreEmptyAndMalformedResponses() async throws {
    for body in ["", "not JSON"] {
        let transport = CoreMockTransport([.init(status: 200, body: body)])
        do { _ = try await MoMoAPIClient(environment: .sandbox, subscriptionKey: "s", transport: transport).execute(CoreEndpoint(), responseType: CoreValue.self); Issue.record("Expected decode error") }
        catch let error as MoMoError {
            if body.isEmpty { if case .emptyResponse = error {} else { Issue.record("Wrong empty error") } }
            else { if case .decodingFailed = error {} else { Issue.record("Wrong malformed error") } }
        }
    }
}
@Test func coreTokenRefreshCoalescesAndCaches() async throws {
    let transport = CoreMockTransport([.init(status: 200, body: "{\"access_token\":\"token\",\"token_type\":\"Bearer\",\"expires_in\":3600}")])
    let provider = MoMoTokenProvider(apiUser: "u", apiKey: "k", tokenPath: "/collection/token/", client: MoMoAPIClient(environment: .sandbox, subscriptionKey: "s", transport: transport))
    let tokens = try await withThrowingTaskGroup(of: String.self) { group in
        for _ in 0..<20 { group.addTask { try await provider.getValidToken() } }
        var values: [String] = []; for try await value in group { values.append(value) }; return values
    }
    #expect(tokens.count == 20); #expect(tokens.allSatisfy { $0 == "token" })
    #expect(try await provider.getValidToken() == "token")
    #expect(await transport.requests.count == 1)
}
@Test func coreTokenFailureRecoveryAndRead401Refresh() async throws {
    let transport = CoreMockTransport([.init(status: 401, body: "{}"), .init(status: 200, body: "{\"access_token\":\"old\",\"token_type\":\"Bearer\",\"expires_in\":3600}"), .init(status: 401, body: "{}"), .init(status: 200, body: "{\"access_token\":\"new\",\"token_type\":\"Bearer\",\"expires_in\":3600}"), .init(status: 200, body: "{\"value\":8}")])
    let client = MoMoAPIClient(environment: .sandbox, subscriptionKey: "s", transport: transport)
    let provider = MoMoTokenProvider(apiUser: "u", apiKey: "k", tokenPath: "/collection/token/", client: client)
    do { _ = try await provider.getValidToken(); Issue.record("Expected token error") } catch {}
    let value = try await client.executeAuthenticated(CoreEndpoint(), responseType: CoreValue.self, tokenProvider: provider)
    #expect(value.value == 8)
    let requests = await transport.requests
    #expect(requests.count == 5); #expect(requests.last?.value(forHTTPHeaderField: "Authorization") == "Bearer new")
}
@Test func corePollingPreservesReferenceAndUnknownStatus() async throws {
    let unknown = try JSONDecoder().decode(TransactionStatus.self, from: Data("\"FUTURE\"".utf8))
    #expect(!unknown.isTerminal); #expect(unknown.rawValue == "FUTURE")
    do { _ = try await MoMoPoller.poll(referenceId: "persisted-id", policy: .init(maxAttempts: 2, interval: 0), operation: { unknown }, isComplete: { $0.isTerminal }); Issue.record("Expected exhausted") }
    catch let error as MoMoError { #expect(error.referenceId == "persisted-id") }
    do { _ = try await MoMoPoller.poll(referenceId: "recover", policy: .init(interval: 0), operation: { () async throws -> TransactionStatus in throw URLError(.timedOut) }, isComplete: { $0.isTerminal }); Issue.record("Expected uncertain") }
    catch let error as MoMoError { #expect(error.referenceId == "recover") }
    #expect(throws: MoMoError.self) { try MoMoPollingPolicy(maxAttempts: 0).validate() }
}
@Test func coreCancellationStopsPoll() async throws {
    let task = Task { try await MoMoPoller.poll(referenceId: "id", policy: .init(interval: 10), operation: { TransactionStatus.pending }, isComplete: { $0.isTerminal }) }
    task.cancel()
    do { _ = try await task.value; Issue.record("Expected cancellation") } catch let error as MoMoError { #expect(error.isCancellation); #expect(error.referenceId == "id") }
}
@Test func coreConsentFormsAndScopedAuthentication() async throws {
    for product in MoMoProduct.allCases {
        let transport = CoreMockTransport([.init(status: 200, body: "{\"auth_req_id\":\"id\",\"interval\":2,\"expires_in\":180}"), .init(status: 200, body: "{\"access_token\":\"consumer\",\"token_type\":\"Bearer\",\"expires_in\":3600}"), .init(status: 200, body: "{\"sub\":\"subscriber\"}")])
        let client = MoMoConsentClient(credentials: .init(apiUser: "u", apiKey: "k", subscriptionKey: "s"), product: product, transport: transport)
        let authorization = try await client.authorize(loginHint: "ID:+233/MSISDN", scopes: ["openid", "profile"], accessType: .offline, bearerToken: "merchant")
        #expect(authorization.authRequestId == "id")
        let token = try await client.exchange(authRequestId: authorization.authRequestId)
        #expect(token.accessToken == "consumer"); #expect(token.refreshToken == nil)
        let info = try await client.userInfo(accessToken: token.accessToken); #expect(info.sub == "subscriber"); #expect(info.email == nil)
        let requests = await transport.requests
        #expect(requests[0].url?.path == "/\(product.rawValue)/v1_0/bc-authorize")
        #expect(requests[0].value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")
        let body = String(data: requests[0].httpBody!, encoding: .utf8)!
        #expect(body.contains("scope=openid%20profile")); #expect(body.contains("login_hint=ID%3A%2B233%2FMSISDN"))
        #expect(requests[0].value(forHTTPHeaderField: "Authorization") == (product == .collection ? "Bearer merchant" : "Basic dTpr"))
        #expect(requests[1].value(forHTTPHeaderField: "Authorization") == "Basic dTpr")
        #expect(requests[2].value(forHTTPHeaderField: "Authorization") == "Bearer consumer")
    }
}
@Test func coreSandboxSeparateLifecycleAndValidation() async throws {
    let transport = CoreMockTransport([.init(status: 201, body: ""), .init(status: 201, body: "{\"apiKey\":\"synthetic\"}"), .init(status: 200, body: "{\"providerCallbackHost\":\"example.test\",\"targetEnvironment\":\"sandbox\"}")])
    let provisioner = MoMoSandboxProvisioner(subscriptionKey: "s", transport: transport)
    let id = try await provisioner.createUser(callbackHost: "example.test")
    #expect(UUID(uuidString: id) != nil)
    #expect(try await provisioner.createKey(referenceId: id) == "synthetic")
    #expect(try await provisioner.getUser(referenceId: id).providerCallbackHost == "example.test")
    let requests = await transport.requests
    #expect(requests[0].value(forHTTPHeaderField: "X-Reference-Id") == id)
    #expect(requests[2].httpMethod == "GET")
    #expect(throws: MoMoError.self) { try MoMoValidation.amount("0") }
    #expect(throws: MoMoError.self) { try MoMoValidation.amount("1e9") }
    try MoMoValidation.amount("9007199254740993.01")
}

@Test func coreLongRetryAfterDoesNotRetryEarly() async throws {
    let transport = CoreMockTransport([.init(status: 429, body: "{}", headers: ["Retry-After": "120"]), .init(status: 200, body: "")])
    do { _ = try await MoMoAPIClient(environment: .sandbox, subscriptionKey: "s", transport: transport, retryPolicy: .init(initialDelay: 0, maximumDelay: 1)).execute(CoreEndpoint()); Issue.record("Expected bounded 429") }
    catch let error as MoMoError { #expect(error.statusCode == 429) }
    #expect(await transport.requests.count == 1)
}
@Test func coreWrite401DoesNotRefreshOrReplay() async throws {
    let transport = CoreMockTransport([.init(status: 200, body: "{\"access_token\":\"old\",\"token_type\":\"Bearer\",\"expires_in\":3600}"), .init(status: 401, body: "{}")])
    let client = MoMoAPIClient(environment: .sandbox, subscriptionKey: "s", transport: transport)
    let provider = MoMoTokenProvider(apiUser: "u", apiKey: "k", tokenPath: "/collection/token/", client: client)
    do { _ = try await client.executeAuthenticated(CoreEndpoint(method: .post), tokenProvider: provider); Issue.record("Expected denied write") }
    catch let error as MoMoError { #expect(error.statusCode == 401) }
    #expect(await transport.requests.count == 2)
}
private final class CoreClock: @unchecked Sendable {
    private let lock = NSLock()
    private var date = Date(timeIntervalSince1970: 1_000)
    func now() -> Date { lock.lock(); defer { lock.unlock() }; return date }
    func advance(_ seconds: Double) { lock.lock(); defer { lock.unlock() }; date.addTimeInterval(seconds) }
}
@Test func coreExpiryAndExplicitInvalidation() async throws {
    let transport = CoreMockTransport((1...3).map { .init(status: 200, body: "{\"access_token\":\"token\($0)\",\"token_type\":\"Bearer\",\"expires_in\":10}") })
    let clock = CoreClock()
    let provider = MoMoTokenProvider(apiUser: "u", apiKey: "k", tokenPath: "/token/", client: MoMoAPIClient(environment: .sandbox, subscriptionKey: "s", transport: transport), now: { clock.now() })
    #expect(try await provider.getValidToken() == "token1")
    clock.advance(8)
    #expect(try await provider.getValidToken() == "token1")
    clock.advance(2)
    #expect(try await provider.getValidToken() == "token2")
    await provider.invalidate(token: "stale")
    #expect(try await provider.getValidToken() == "token2")
    await provider.invalidate()
    #expect(try await provider.getValidToken() == "token3")
}

@Test func coreOptionalConsentFieldsMatchPayoutExports() async throws {
    for product in [MoMoProduct.disbursement, .remittance] {
        let transport = CoreMockTransport([.init(status: 200, body: "{\"auth_req_id\":\"id\",\"interval\":2,\"expires_in\":180}")])
        let client = MoMoConsentClient(credentials: .init(apiUser: "u", apiKey: "k", subscriptionKey: "s"), product: product, transport: transport)
        _ = try await client.authorize(loginHint: "ID:233/MSISDN", scopes: ["openid"], consentValidIn: 180, clientNotificationToken: "notify+&token", scopeInstruction: "operator instruction")
        let requests = await transport.requests
        let body = String(data: requests[0].httpBody!, encoding: .utf8)!
        #expect(body.contains("consent_valid_in=180"))
        #expect(body.contains("client_notification_token=notify%2B%26token"))
        #expect(body.contains("scope_instruction=operator%20instruction"))
    }
    let transport = CoreMockTransport([])
    let client = MoMoConsentClient(credentials: .init(apiUser: "u", apiKey: "k", subscriptionKey: "s"), product: .collection, transport: transport)
    do { _ = try await client.authorize(loginHint: "ID:233/MSISDN", scopes: ["openid"], bearerToken: "token", consentValidIn: 180); Issue.record("Expected unsupported field") } catch is MoMoError {}
    #expect(await transport.requests.isEmpty)
    #expect(throws: MoMoError.self) { try MoMoValidation.referenceId("00000000-0000-1000-8000-000000000000") }
    try MoMoValidation.referenceId("00000000-0000-4000-8000-000000000000")
}

@Test func coreConsentSupportsBothExportedAddressShapesAndNumbers() throws {
    let info = try JSONDecoder().decode(MoMoConsentUserInfo.self, from: Data(#"{"address":{"formatted":"Accra","street_address":"1 Main St","locality":"Accra","region":"Greater Accra","postal_code":"GA","country":"Ghana"},"updated_at":1000.5}"#.utf8))
    #expect(info.address?.country == "Ghana")
    #expect(info.address?.streetAddress == "1 Main St")
    #expect(info.updatedAt == 1000.5)
    let text = try JSONDecoder().decode(MoMoConsentUserInfo.self, from: Data(#"{"address":"Accra"}"#.utf8))
    #expect(text.address?.formatted == "Accra")
    #expect(text.address?.country == nil)
    let authorization = try JSONDecoder().decode(MoMoConsentAuthorization.self, from: Data(#"{"auth_req_id":"id","interval":1.5,"expires_in":180.5}"#.utf8))
    #expect(authorization.interval == 1.5)
    #expect(authorization.expiresIn == 180.5)
    let token = try JSONDecoder().decode(MoMoConsentToken.self, from: Data(#"{"access_token":"token","token_type":"Bearer","expires_in":3600.5,"refresh_token_expired_in":86400}"#.utf8))
    #expect(token.expiresIn == 3600.5)
    #expect(token.refreshTokenExpiredIn == 86400)
}

@Test func coreRejectsNonRFCUUIDVariant() throws {
    #expect(throws: MoMoError.self) { try MoMoValidation.referenceId("00000000-0000-4000-0000-000000000000") }
    try MoMoValidation.referenceId(UUID().uuidString)
}
