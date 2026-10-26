import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
import MoMoCore
import MoMoCollections
import MoMoDisbursements
@testable import MoMoDemoViewModels

private enum DemoScript: Sendable {
    case tokenUnauthorizedOnce
    case tokenTimeoutOnce
    case tokenCancellationOnce
    case invalidTokenOnce
    case postTimeout
    case postCancellation
    case statusNotFound
    case statusAuthorizationFailure
    case statusCancellation
    case success
    case failed
}

private actor DemoTransport: MoMoHTTPTransport {
    private let script: DemoScript
    private var tokenCount = 0
    private var postCount = 0
    private var statusCount = 0
    private(set) var requests: [URLRequest] = []

    init(_ script: DemoScript) { self.script = script }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let path = request.url!.path
        if path.hasSuffix("/token") || path.hasSuffix("/token/") {
            tokenCount += 1
            if tokenCount == 1 {
                switch script {
                case .tokenUnauthorizedOnce:
                    return response(request, 401, #"{"code":"INVALID_CREDENTIALS"}"#)
                case .tokenTimeoutOnce:
                    throw URLError(.timedOut)
                case .tokenCancellationOnce:
                    throw CancellationError()
                case .invalidTokenOnce:
                    return response(request, 200, #"{"access_token":"","token_type":"Bearer","expires_in":3600}"#)
                default:
                    break
                }
            }
            if case .statusAuthorizationFailure = script, tokenCount > 1 {
                return response(request, 401, #"{"code":"INVALID_CREDENTIALS"}"#)
            }
            return response(request, 200, #"{"access_token":"synthetic","token_type":"Bearer","expires_in":3600}"#)
        }

        if request.httpMethod == "POST" {
            postCount += 1
            switch script {
            case .postTimeout: throw URLError(.timedOut)
            case .postCancellation: throw CancellationError()
            default: return response(request, 202, "")
            }
        }

        statusCount += 1
        switch script {
        case .statusNotFound:
            return response(request, 404, #"{"code":"RESOURCE_NOT_FOUND"}"#)
        case .statusAuthorizationFailure:
            return response(request, 401, #"{"code":"UNAUTHORIZED"}"#)
        case .statusCancellation:
            throw CancellationError()
        case .success:
            return response(request, 200, #"{"status":"SUCCESSFUL"}"#)
        case .failed:
            return response(request, 200, #"{"status":"FAILED","reason":{"code":"DECLINED","message":"declined"}}"#)
        default:
            return response(request, 404, #"{"code":"RESOURCE_NOT_FOUND"}"#)
        }
    }

    func financialPostCount() -> Int { postCount }
    func statusRequestCount() -> Int { statusCount }
    func requestCount() -> Int { requests.count }

    private func response(_ request: URLRequest, _ code: Int, _ body: String) -> (Data, HTTPURLResponse) {
        (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: nil)!)
    }
}

private struct IsolatedDefaults {
    let suiteName: String
    let value: UserDefaults

    init() {
        suiteName = "momo.issue9.tests.\(UUID().uuidString)"
        value = UserDefaults(suiteName: suiteName)!
        value.removePersistentDomain(forName: suiteName)
    }

    func clear() { value.removePersistentDomain(forName: suiteName) }
}

private enum DemoFlow: CaseIterable {
    case collection
    case deposit

    @MainActor func makeModel(transport: any MoMoHTTPTransport, defaults: UserDefaults) -> DemoModel {
        let credentials = MoMoCredentials(apiUser: "user", apiKey: "key", subscriptionKey: "subscription")
        switch self {
        case .collection:
            let client = MoMoCollectionClient(credentials: credentials, environment: .sandbox, transport: transport, retryPolicy: .none)
            return .checkout(CheckoutViewModel(client: client, defaults: defaults))
        case .deposit:
            let client = MoMoDisbursementClient(credentials: credentials, environment: .sandbox, transport: transport, retryPolicy: .none)
            return .deposit(DepositViewModel(client: client, defaults: defaults))
        }
    }

    var referenceKey: String {
        switch self {
        case .collection: "momo.demo.collection.reference"
        case .deposit: "momo.demo.deposit.reference"
        }
    }
}

@MainActor
private enum DemoModel {
    case checkout(CheckoutViewModel)
    case deposit(DepositViewModel)

    var referenceId: String? {
        switch self {
        case .checkout(let model): model.referenceId
        case .deposit(let model): model.referenceId
        }
    }

    var hasUnresolvedRequest: Bool {
        switch self {
        case .checkout(let model): model.hasUnresolvedRequest
        case .deposit(let model): model.hasUnresolvedRequest
        }
    }

    var transactionStatus: String {
        switch self {
        case .checkout(let model): model.transactionStatus
        case .deposit(let model): model.transactionStatus
        }
    }

    func submit() async {
        switch self {
        case .checkout(let model):
            await model.simulatePurchase(phoneNumber: "46700000000", amount: "1", currency: "EUR", payerMessage: "Test", payeeNote: "Test", deliveryNote: "")
        case .deposit(let model):
            await model.simulateDeposit(phoneNumber: "46700000000", amount: "1", currency: "EUR", payerMessage: "Test", payeeNote: "Test")
        }
    }

    func checkExistingRequest() async {
        switch self {
        case .checkout(let model): await model.checkExistingRequest()
        case .deposit(let model): await model.checkExistingRequest()
        }
    }
}

@Test @MainActor func knownPreSubmissionFailuresClearStateAndAllowRetryAfterRestoration() async throws {
    for flow in DemoFlow.allCases {
        for script in [DemoScript.tokenUnauthorizedOnce, .tokenTimeoutOnce, .tokenCancellationOnce, .invalidTokenOnce] {
            let isolated = IsolatedDefaults()
            defer { isolated.clear() }
            let transport = DemoTransport(script)
            let first = flow.makeModel(transport: transport, defaults: isolated.value)
            await first.submit()

            #expect(first.referenceId == nil)
            #expect(!first.hasUnresolvedRequest)
            #expect(isolated.value.string(forKey: flow.referenceKey) == nil)
            #expect(isolated.value.object(forKey: flow.referenceKey + ".unresolved") == nil)
            #expect(first.transactionStatus == "Request was not sent. You can try again.")
            #expect(await transport.financialPostCount() == 0)

            let restored = flow.makeModel(transport: transport, defaults: isolated.value)
            #expect(restored.referenceId == nil)
            #expect(!restored.hasUnresolvedRequest)
            await restored.submit()

            #expect(restored.referenceId != nil)
            #expect(restored.hasUnresolvedRequest)
            #expect(isolated.value.string(forKey: flow.referenceKey) == restored.referenceId)
            #expect(isolated.value.bool(forKey: flow.referenceKey + ".unresolved"))
            #expect(await transport.financialPostCount() == 1)
        }
    }
}

@Test @MainActor func postDispatchCancellationAndLostResponseRemainUnresolvedAndBlockReplay() async throws {
    for flow in DemoFlow.allCases {
        for script in [DemoScript.postTimeout, .postCancellation] {
            let isolated = IsolatedDefaults()
            defer { isolated.clear() }
            let transport = DemoTransport(script)
            let first = flow.makeModel(transport: transport, defaults: isolated.value)
            await first.submit()
            let savedReference = try #require(first.referenceId)

            #expect(first.hasUnresolvedRequest)
            #expect(isolated.value.string(forKey: flow.referenceKey) == savedReference)
            #expect(isolated.value.bool(forKey: flow.referenceKey + ".unresolved"))
            #expect(await transport.financialPostCount() == 1)

            let restored = flow.makeModel(transport: transport, defaults: isolated.value)
            #expect(restored.referenceId == savedReference)
            #expect(restored.hasUnresolvedRequest)
            await restored.submit()
            #expect(await transport.financialPostCount() == 1)
        }
    }
}

@Test @MainActor func statusNotFoundDoesNotUnlockOrReplayEitherFinancialFlow() async throws {
    for flow in DemoFlow.allCases {
        let isolated = IsolatedDefaults()
        defer { isolated.clear() }
        let transport = DemoTransport(.statusNotFound)
        let model = flow.makeModel(transport: transport, defaults: isolated.value)
        await model.submit()
        let savedReference = try #require(model.referenceId)
        #expect(model.hasUnresolvedRequest)

        let restored = flow.makeModel(transport: transport, defaults: isolated.value)
        #expect(restored.referenceId == savedReference)
        #expect(restored.hasUnresolvedRequest)
        await restored.checkExistingRequest()
        #expect(restored.referenceId == savedReference)
        #expect(restored.hasUnresolvedRequest)
        await restored.submit()
        #expect(await transport.financialPostCount() == 1)
        #expect(await transport.statusRequestCount() == 2)
    }
}

@Test @MainActor func statusAuthenticationAndCancellationErrorsKeepRestoredReferences() async throws {
    for flow in DemoFlow.allCases {
        for script in [DemoScript.statusAuthorizationFailure, .statusCancellation] {
            let isolated = IsolatedDefaults()
            defer { isolated.clear() }
            let savedReference = UUID().uuidString.lowercased()
            isolated.value.set(savedReference, forKey: flow.referenceKey)
            isolated.value.set(true, forKey: flow.referenceKey + ".unresolved")
            let transport = DemoTransport(script)
            let restored = flow.makeModel(transport: transport, defaults: isolated.value)
            await restored.checkExistingRequest()

            #expect(restored.referenceId == savedReference)
            #expect(restored.hasUnresolvedRequest)
            #expect(isolated.value.string(forKey: flow.referenceKey) == savedReference)
            #expect(isolated.value.bool(forKey: flow.referenceKey + ".unresolved"))

            let nextLaunch = flow.makeModel(transport: transport, defaults: isolated.value)
            await nextLaunch.submit()
            #expect(await transport.financialPostCount() == 0)
        }
    }
}

@Test @MainActor func terminalStatusResolvesReferencesForBothFlows() async throws {
    for flow in DemoFlow.allCases {
        for script in [DemoScript.success, .failed] {
            let isolated = IsolatedDefaults()
            defer { isolated.clear() }
            let transport = DemoTransport(script)
            let model = flow.makeModel(transport: transport, defaults: isolated.value)
            await model.submit()

            #expect(model.referenceId != nil)
            #expect(!model.hasUnresolvedRequest)
            #expect(isolated.value.string(forKey: flow.referenceKey) == model.referenceId)
            #expect(!isolated.value.bool(forKey: flow.referenceKey + ".unresolved"))
            #expect(await transport.financialPostCount() == 1)
            #expect(await transport.statusRequestCount() == 1)
        }
    }
}

private actor GatedTokenTransport: MoMoHTTPTransport {
    private var tokenRequestStarted = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var tokenResponse: CheckedContinuation<(Data, HTTPURLResponse), Never>?
    private(set) var requests: [URLRequest] = []
    private var postCount = 0

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        if request.url!.path.hasSuffix("/token") || request.url!.path.hasSuffix("/token/") {
            tokenRequestStarted = true
            startWaiters.forEach { $0.resume() }
            startWaiters.removeAll()
            return await withCheckedContinuation { tokenResponse = $0 }
        }
        if request.httpMethod == "POST" { postCount += 1 }
        return (Data(), HTTPURLResponse(url: request.url!, statusCode: 202, httpVersion: nil, headerFields: nil)!)
    }

    func waitUntilTokenRequestStarts() async {
        if tokenRequestStarted { return }
        await withCheckedContinuation { startWaiters.append($0) }
    }

    func releaseTokenResponse() {
        guard let tokenResponse else { return }
        self.tokenResponse = nil
        tokenResponse.resume(returning: (Data(#"{"access_token":"synthetic","token_type":"Bearer","expires_in":3600}"#.utf8), HTTPURLResponse(url: URL(string: "https://sandbox.momodeveloper.mtn.com/collection/token/")!, statusCode: 200, httpVersion: nil, headerFields: nil)!))
    }

    func financialPostCount() -> Int { postCount }
}

@Test @MainActor func cancellingWhileTokenRefreshIsGatedClearsReferenceBeforeAnyFinancialDispatch() async throws {
    for flow in DemoFlow.allCases {
        let isolated = IsolatedDefaults()
        defer { isolated.clear() }
        let transport = GatedTokenTransport()
        let model = flow.makeModel(transport: transport, defaults: isolated.value)
        let submission = Task { @MainActor in await model.submit() }
        await transport.waitUntilTokenRequestStarts()
        submission.cancel()
        await transport.releaseTokenResponse()
        await submission.value

        #expect(model.referenceId == nil)
        #expect(!model.hasUnresolvedRequest)
        #expect(model.transactionStatus == "Request was not sent. You can try again.")
        #expect(isolated.value.string(forKey: flow.referenceKey) == nil)
        #expect(isolated.value.object(forKey: flow.referenceKey + ".unresolved") == nil)
        #expect(await transport.financialPostCount() == 0)

        let restored = flow.makeModel(transport: transport, defaults: isolated.value)
        #expect(restored.referenceId == nil)
        #expect(!restored.hasUnresolvedRequest)
    }
}
