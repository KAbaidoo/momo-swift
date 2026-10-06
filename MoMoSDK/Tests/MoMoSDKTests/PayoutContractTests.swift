import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
import MoMoCore
import MoMoDisbursements
import MoMoRemittance

private actor PayoutTransport: MoMoHTTPTransport {
    struct Stub: Sendable { let code: Int; let body: String }
    var requests: [URLRequest] = []
    var stubs: [Stub]
    init(_ stubs: [Stub]) { self.stubs = stubs }
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let stub = stubs.removeFirst()
        return (Data(stub.body.utf8), HTTPURLResponse(url: request.url!, statusCode: stub.code, httpVersion: nil, headerFields: nil)!)
    }
}
private let payoutCredentials = MoMoCredentials(apiUser: "test-user", apiKey: "test-key", subscriptionKey: "test-subscription")
private let tokenStub = PayoutTransport.Stub(code: 200, body: #"{"access_token":"token","token_type":"Bearer","expires_in":3600}"#)
private let payoutParty = Party(partyIdType: .msisdn, partyId: "233240000000")

@Test func payoutTransferWireContract() async throws {
    let transport = PayoutTransport([tokenStub, .init(code: 202, body: ""), .init(code: 200, body: #"{"status":"FAILED","payee":{"partyIdType":"MSISDN","partyId":"233240000000"},"reason":{"code":"NEW_CODE"}}"#)])
    let client = MoMoDisbursementClient(credentials: payoutCredentials, environment: .sandbox, transport: transport)
    let id = UUID()
    let result = try await client.transfer(payload: TransferRequest(amount: "0.123456789", currency: "GHS", payee: payoutParty, payeeNote: "note"), referenceId: id, callbackURL: "https://callback.example/pay")
    #expect(result == id.uuidString.lowercased())
    let status = try await client.getTransferStatus(referenceId: result)
    #expect(status.payee == payoutParty)
    #expect(status.reason?.message == nil)
    let requests = await transport.requests
    #expect(requests[0].url?.absoluteString.hasSuffix("/disbursement/token/") == true)
    #expect(requests[1].httpMethod == "POST")
    #expect(requests[1].value(forHTTPHeaderField: "X-Reference-Id") == result)
    #expect(requests[1].value(forHTTPHeaderField: "X-Callback-Url") == "https://callback.example/pay")
    let body = try JSONSerialization.jsonObject(with: requests[1].httpBody!) as! [String: Any]
    #expect(body["payeeNote"] as? String == "note")
    #expect(body["payerNote"] == nil)
    #expect(body["amount"] as? String == "0.123456789")
}

@Test func payoutDepositAndRefundVersionRoutes() async throws {
    for version in [DisbursementAPIVersion.v1, .v2] {
        let transport = PayoutTransport([tokenStub, .init(code: 202, body: ""), .init(code: 200, body: #"{"status":"SUCCESSFUL"}"#), .init(code: 202, body: ""), .init(code: 200, body: #"{"status":"FAILED"}"#)])
        let client = MoMoDisbursementClient(credentials: payoutCredentials, environment: .sandbox, transport: transport)
        let id = try await client.deposit(payload: DepositRequest(amount: "2", currency: "EUR", payee: payoutParty), version: version)
        #expect(try await client.getDepositStatus(referenceId: id).status == .successful)
        let refund = try await client.refund(payload: RefundRequest(amount: "1", currency: "EUR", referenceIdToRefund: id), version: version)
        #expect(try await client.getRefundStatus(referenceId: refund).status == .failed)
        let requests = await transport.requests
        #expect(requests[1].url?.path == "/disbursement/\(version.rawValue)/deposit")
        #expect(requests[2].url?.path == "/disbursement/v1_0/deposit/\(id)")
        #expect(requests[3].url?.path == "/disbursement/\(version.rawValue)/refund")
        #expect(requests[4].url?.path == "/disbursement/v1_0/refund/\(refund)")
    }
}

@Test func payoutInvalidInputsNeverReachNetwork() async throws {
    for amount in ["0", "-1", "NaN", "1e3", " 1", "1,2"] {
        let transport = PayoutTransport([])
        let client = MoMoDisbursementClient(credentials: payoutCredentials, environment: .sandbox, transport: transport)
        await #expect(throws: MoMoError.self) { try await client.transfer(payload: TransferRequest(amount: amount, currency: "EUR", payee: payoutParty)) }
        #expect(await transport.requests.isEmpty)
    }
    let transport = PayoutTransport([])
    let client = MoMoDisbursementClient(credentials: payoutCredentials, environment: .sandbox, transport: transport)
    await #expect(throws: MoMoError.self) { try await client.depositAndWait(payload: DepositRequest(amount: "1", currency: "EUR", payee: payoutParty), policy: .init(maxAttempts: 0)) }
    await #expect(throws: MoMoError.self) { try await client.getTransferStatus(referenceId: "../bad") }
    await #expect(throws: MoMoError.self) { try await client.transfer(payload: TransferRequest(amount: "1", currency: "EUR", payee: payoutParty), callbackURL: "http://callback.example") }
    #expect(await transport.requests.isEmpty)
}

@Test func payoutUnknownStatusPollsAndPreservesReference() async throws {
    let transport = PayoutTransport([tokenStub, .init(code: 202, body: ""), .init(code: 200, body: #"{"status":"PROCESSING_NEW"}"#), .init(code: 200, body: #"{"status":"PENDING"}"#)])
    let client = MoMoDisbursementClient(credentials: payoutCredentials, environment: .sandbox, transport: transport)
    let reference = UUID()
    do {
        _ = try await client.transferAndWait(payload: TransferRequest(amount: "1", currency: "EUR", payee: payoutParty), referenceId: reference, policy: .init(maxAttempts: 2, interval: 0))
        Issue.record("Expected polling exhaustion")
    } catch let error as MoMoError { #expect(error.referenceId == reference.uuidString.lowercased()) }
    #expect(await transport.requests.count == 4)
}

@Test func payoutAccountsHonorFalseAndEncodedSegments() async throws {
    let transport = PayoutTransport([tokenStub, .init(code: 200, body: "false"), .init(code: 200, body: #"{"availableBalance":"100.00","currency":"EUR"}"#), .init(code: 200, body: #"{"given_name":"Ada"}"#)])
    let client = MoMoDisbursementClient(credentials: payoutCredentials, environment: .sandbox, transport: transport)
    let party = Party(partyIdType: .email, partyId: "name/a?x@example.com")
    #expect(try await client.isAccountHolderActive(party: party) == false)
    _ = try await client.getAccountBalance(currency: "EUR")
    #expect(try await client.getBasicUserInfo(party: party).givenName == "Ada")
    let requests = await transport.requests
    #expect(requests[1].url?.absoluteString.contains("name%2Fa%3Fx%40example.com") == true)
    #expect(requests[2].url?.path == "/disbursement/v1_0/account/balance/EUR")
}

@Test func payoutWriteFailureNeverRetriesAndKeepsCallerReference() async throws {
    let transport = PayoutTransport([tokenStub, .init(code: 503, body: #"{"code":"SERVICE_UNAVAILABLE","message":"temporary"}"#)])
    let client = MoMoDisbursementClient(credentials: payoutCredentials, environment: .sandbox, transport: transport)
    let id = UUID()
    do {
        _ = try await client.deposit(payload: DepositRequest(amount: "1", currency: "EUR", payee: payoutParty), referenceId: id)
        Issue.record("Expected write failure")
    } catch let error as MoMoError {
        #expect(error.referenceId == id.uuidString.lowercased())
        #expect(error.statusCode == 503)
    }
    #expect(await transport.requests.count == 2)
}

@Test func payoutAccount404IsFalseButServerFailurePropagates() async throws {
    let transport = PayoutTransport([tokenStub, .init(code: 404, body: ""), .init(code: 503, body: "")])
    let client = MoMoDisbursementClient(credentials: payoutCredentials, environment: .sandbox, transport: transport, retryPolicy: .init(maxAttempts: 1, initialDelay: 0, maximumDelay: 0))
    #expect(try await client.isAccountHolderActive(party: payoutParty) == false)
    await #expect(throws: MoMoError.self) { try await client.isAccountHolderActive(party: payoutParty) }
}

@Test func payoutBasicInfoIdentityCasingAndAliases() async throws {
    let transport = PayoutTransport([tokenStub, .init(code: 200, body: "{}"), .init(code: 200, body: "{}")])
    let client = MoMoDisbursementClient(credentials: payoutCredentials, environment: .sandbox, transport: transport)
    _ = try await client.getBasicUserInfo(party: payoutParty)
    _ = try await client.getBasicUserInfo(identity: .init(kind: .alias, value: "a/b"))
    let requests = await transport.requests
    #expect(requests[1].url?.absoluteString.contains("/MSISDN/") == true)
    #expect(requests[2].url?.absoluteString.contains("/alias/a%2Fb/") == true)
    await #expect(throws: MoMoError.self) {
        _ = try await client.getBasicUserInfo(party: Party(partyIdType: .partyCode, partyId: "unsupported"))
    }
    #expect(await transport.requests.count == 3)
}

private actor CancelledFinancialTransport: MoMoHTTPTransport {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        if request.url!.path.contains("/token") {
            return (Data(tokenStub.body.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        throw CancellationError()
    }
}
@Test func payoutCancelledSubmissionPreservesGeneratedReference() async throws {
    let client = MoMoDisbursementClient(credentials: payoutCredentials, environment: .sandbox, transport: CancelledFinancialTransport())
    do {
        _ = try await client.deposit(payload: .init(amount: "1", currency: "EUR", payee: payoutParty))
        Issue.record("Expected cancelled submission")
    } catch let error as MoMoError {
        #expect(error.isCancellation)
        #expect(UUID(uuidString: error.referenceId ?? "") != nil)
    }
}
