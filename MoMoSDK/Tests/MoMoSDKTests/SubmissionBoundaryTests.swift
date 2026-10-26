import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
import MoMoCore
import MoMoCollections
import MoMoDisbursements

private enum BoundaryFailure: Sendable {
    case cancellation
    case timeout
}

private enum BoundaryStep: Sendable {
    case response(Int, String)
    case failure(BoundaryFailure)
}

private actor BoundaryTransport: MoMoHTTPTransport {
    private var steps: [BoundaryStep]
    private(set) var requests: [URLRequest] = []

    init(_ steps: [BoundaryStep]) { self.steps = steps }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        guard !steps.isEmpty else { throw URLError(.badServerResponse) }
        switch steps.removeFirst() {
        case .failure(.cancellation): throw CancellationError()
        case .failure(.timeout): throw URLError(.timedOut)
        case .response(let code, let body):
            return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: nil)!)
        }
    }
}

private struct SubmissionEndpoint: MoMoEndpoint {
    var path = "/collection/v1_0/requesttopay"
    var method: HTTPMethod = .post
    var shouldFailBody = false
    var cancelInBody = false

    func body() throws -> Data? {
        if cancelInBody {
            withUnsafeCurrentTask { $0?.cancel() }
            return Data("{}".utf8)
        }
        if shouldFailBody { throw MoMoError.invalidConfiguration("synthetic body failure") }
        return Data("{}".utf8)
    }
}

private let boundaryCredentials = MoMoCredentials(apiUser: "user", apiKey: "key", subscriptionKey: "subscription")
private let boundaryReference = "abcdef12-3456-4789-abcd-012345678901"
private let validToken = #"{"access_token":"synthetic","token_type":"Bearer","expires_in":3600}"#

private func boundaryClient(_ transport: BoundaryTransport) -> (MoMoAPIClient, MoMoTokenProvider) {
    let client = MoMoAPIClient(environment: .sandbox, subscriptionKey: boundaryCredentials.subscriptionKey, transport: transport, retryPolicy: .none)
    let provider = MoMoTokenProvider(apiUser: boundaryCredentials.apiUser, apiKey: boundaryCredentials.apiKey, tokenPath: "/collection/token/", client: client)
    return (client, provider)
}

private func checkPreSubmissionFailure(
    _ operation: () async throws -> Void,
    referenceId: String = boundaryReference,
    statusCode: Int? = nil
) async {
    do {
        try await operation()
        Issue.record("Expected a known pre-submission failure")
    } catch let error as MoMoError {
        #expect(error.isKnownPreSubmissionFailure)
        #expect(error.referenceId == referenceId)
        #expect(error.statusCode == statusCode)
    } catch {
        Issue.record("Expected MoMoError pre-submission classification, got \(error)")
    }
}

@Test func submissionTokenFailuresAreKnownPreDispatchAndNeverPost() async throws {
    for step in [
        BoundaryStep.response(401, #"{"code":"INVALID_TOKEN"}"#),
        .failure(.timeout),
        .response(200, #"{"access_token":"","token_type":"Bearer","expires_in":3600}"#)
    ] {
        let transport = BoundaryTransport([step])
        let (client, provider) = boundaryClient(transport)
        await checkPreSubmissionFailure({
            _ = try await client.executeAuthenticatedSubmission(SubmissionEndpoint(), referenceId: boundaryReference, tokenProvider: provider)
        }, statusCode: {
            if case .response(let code, _) = step { return code == 401 ? 401 : nil }
            return nil
        }())
        let requests = await transport.requests
        #expect(requests.count == 1)
        #expect(requests.allSatisfy { $0.url?.path.contains("/token") == true })
    }
}

@Test func submissionLocalPreflightFailureIsKnownAndNeverDispatched() async throws {
    let transport = BoundaryTransport([.response(200, validToken)])
    let (client, provider) = boundaryClient(transport)
    _ = try await provider.getValidToken()
    await checkPreSubmissionFailure({
        _ = try await client.executeAuthenticatedSubmission(SubmissionEndpoint(shouldFailBody: true), referenceId: boundaryReference, tokenProvider: provider)
    })
    #expect(await transport.requests.count == 1)
}

@Test func submissionCachedTokenCancellationBeforeTransportIsKnownPreDispatch() async throws {
    let transport = BoundaryTransport([.response(200, validToken)])
    let (client, provider) = boundaryClient(transport)
    _ = try await provider.getValidToken()

    let task = Task {
        try await client.executeAuthenticatedSubmission(SubmissionEndpoint(cancelInBody: true), referenceId: boundaryReference, tokenProvider: provider)
    }
    do {
        _ = try await task.value
        Issue.record("Expected cancellation before dispatch")
    } catch let error as MoMoError {
        #expect(error.isKnownPreSubmissionFailure)
        #expect(error.isCancellation)
        #expect(error.referenceId == boundaryReference)
    }
    #expect(await transport.requests.count == 1)
}

@Test func submissionTransportCancellationAndLostResponseStayUncertainAndNeverReplay() async throws {
    for failure in [BoundaryFailure.cancellation, .timeout] {
        let transport = BoundaryTransport([.response(200, validToken), .failure(failure)])
        let (client, provider) = boundaryClient(transport)
        do {
            _ = try await client.executeAuthenticatedSubmission(SubmissionEndpoint(), referenceId: boundaryReference, tokenProvider: provider)
            Issue.record("Expected an uncertain submission result")
        } catch let error as MoMoError {
            #expect(!error.isKnownPreSubmissionFailure)
            #expect(error.referenceId == boundaryReference)
            if case .transactionFailure = error {} else { Issue.record("Expected transactionFailure after transport invocation") }
            if case .cancellation = failure { #expect(error.isCancellation) }
        }
        let requests = await transport.requests
        #expect(requests.count == 2)
        #expect(requests.filter { $0.httpMethod == "POST" && $0.url?.path == "/collection/v1_0/requesttopay" }.count == 1)
    }
}

@Test func uncertainOuterClassificationDoesNotBecomeKnownPreSubmission() {
    let preflight = MoMoError.preSubmissionFailure(referenceId: boundaryReference, underlying: CancellationError())
    let uncertain = MoMoError.transactionFailure(referenceId: boundaryReference, underlying: preflight)
    #expect(preflight.isKnownPreSubmissionFailure)
    #expect(preflight.isCancellation)
    #expect(uncertain.referenceId == boundaryReference)
    #expect(uncertain.isCancellation)
    #expect(!uncertain.isKnownPreSubmissionFailure)
}

@Test func requestToPayAndDepositValidationFailuresCarryReferenceWithoutNetwork() async throws {
    let invalidRequest = RequestToPayRequest(amount: "0", currency: "EUR", externalId: "order", payer: Party(partyIdType: .msisdn, partyId: "46700000000"), payerMessage: "test", payeeNote: "test")
    let collectionTransport = BoundaryTransport([])
    let collection = MoMoCollectionClient(credentials: boundaryCredentials, environment: .sandbox, transport: collectionTransport, retryPolicy: .none)
    await checkPreSubmissionFailure({ _ = try await collection.requestToPay(payload: invalidRequest, referenceId: UUID(uuidString: boundaryReference)!) })
    #expect(await collectionTransport.requests.isEmpty)

    let depositTransport = BoundaryTransport([])
    let disbursement = MoMoDisbursementClient(credentials: boundaryCredentials, environment: .sandbox, transport: depositTransport, retryPolicy: .none)
    await checkPreSubmissionFailure({
        _ = try await disbursement.deposit(payload: .init(amount: "0", currency: "EUR", payee: Party(partyIdType: .msisdn, partyId: "46700000000")), referenceId: UUID(uuidString: boundaryReference)!)
    })
    #expect(await depositTransport.requests.isEmpty)
}
