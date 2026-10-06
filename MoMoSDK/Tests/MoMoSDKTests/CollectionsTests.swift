import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
import MoMoCore
@testable import MoMoCollections

private actor CollectionTransport: MoMoHTTPTransport {
    struct Reply: Sendable { let code: Int; let body: String }
    private var replies: [Reply]
    private var requests: [URLRequest] = []
    init(_ replies: [Reply]) { self.replies = replies }
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let reply: Reply
        if request.url!.path.hasSuffix("/token") || request.url!.path.hasSuffix("/token/") {
            reply = .init(code: 200, body: #"{"access_token":"synthetic","token_type":"Bearer","expires_in":3600}"#)
        } else {
            guard !replies.isEmpty else { throw URLError(.badServerResponse) }
            reply = replies.removeFirst()
        }
        return (Data(reply.body.utf8), HTTPURLResponse(url: request.url!, statusCode: reply.code, httpVersion: nil, headerFields: nil)!)
    }
    func operations() -> [URLRequest] { requests.filter { !$0.url!.path.hasSuffix("/token") && !$0.url!.path.hasSuffix("/token/") } }
    func allRequests() -> [URLRequest] { requests }
}
private func collectionClient(_ transport: CollectionTransport) -> MoMoCollectionClient {
    .init(credentials: .init(apiUser: "user", apiKey: "key", subscriptionKey: "subscription"), environment: .sandbox, transport: transport, retryPolicy: .none)
}
private let collectionParty = Party(partyIdType: .msisdn, partyId: "46700000000")
private let collectionReference = UUID(uuidString: "ABCDEF12-3456-4789-ABCD-012345678901")!
private var collectionRequest: RequestToPayRequest { .init(amount: "12.00", currency: "EUR", externalId: "order", payer: collectionParty, payerMessage: "Pay", payeeNote: "Order") }
private func collectionBody(_ request: URLRequest) throws -> [String: Any] {
    let data = try #require(request.httpBody)
    let object = try JSONSerialization.jsonObject(with: data)
    return try #require(object as? [String: Any])
}

@Test func collectionsRequestToPayWireAndDeliveryHeaders() async throws {
    let transport = CollectionTransport([.init(code: 202, body: ""), .init(code: 200, body: "")])
    let client = collectionClient(transport)
    let id = try await client.requestToPay(payload: collectionRequest, referenceId: collectionReference, callbackURL: "https://example.com/callback")
    try await client.sendDeliveryNotification(for: id, message: "Delivered", language: "en")
    let requests = await transport.operations()
    #expect(id == "abcdef12-3456-4789-abcd-012345678901")
    #expect(requests[0].url!.path == "/collection/v1_0/requesttopay")
    #expect(requests[0].httpMethod == "POST")
    #expect(requests[0].value(forHTTPHeaderField: "X-Reference-Id") == id)
    #expect(requests[0].value(forHTTPHeaderField: "X-Callback-Url") == "https://example.com/callback")
    #expect(requests[0].value(forHTTPHeaderField: "Authorization") == "Bearer synthetic")
    let body = try collectionBody(requests[0])
    #expect(Set(body.keys) == Set(["amount", "currency", "externalId", "payer", "payerMessage", "payeeNote"]))
    #expect(body["amount"] as? String == "12.00")
    #expect(requests[1].value(forHTTPHeaderField: "notificationMessage") == "Delivered")
    #expect(requests[1].value(forHTTPHeaderField: "Language") == "en")
    #expect(try collectionBody(requests[1])["notificationMessage"] as? String == "Delivered")
}

@Test func collectionsInvoiceV2AndCancellationContract() async throws {
    let transport = CollectionTransport([.init(code: 202, body: ""), .init(code: 200, body: #"{"status":"CREATED","invoiceId":"invoice","errorReason":{"code":"CUSTOM"}}"#), .init(code: 200, body: #"{"externalId":"cancel-order"}"#)])
    let client = collectionClient(transport)
    let id = try await client.createInvoice(payload: .init(externalId: "order", amount: "1", currency: "EUR", validityDuration: "60", intendedPayer: collectionParty, payee: collectionParty), referenceId: collectionReference)
    let status = try await client.getInvoiceStatus(referenceId: id)
    #expect(status.status == .created)
    #expect(!status.status.isTerminal)
    #expect(status.errorReason?.code == "CUSTOM")
    try await client.cancelInvoice(invoiceReferenceId: id, externalId: "cancel-order", referenceId: collectionReference, callbackURL: "https://example.com/callback")
    let requests = await transport.operations()
    #expect(requests.map { $0.url!.path } == ["/collection/v2_0/invoice", "/collection/v2_0/invoice/\(id)", "/collection/v2_0/invoice/\(id)"])
    #expect(try collectionBody(requests[0])["validityDuration"] as? String == "60")
    #expect(try collectionBody(requests[0])["payee"] != nil)
    #expect(requests[2].httpMethod == "DELETE")
    #expect(requests[2].value(forHTTPHeaderField: "X-Reference-Id") == id)
    #expect(requests[2].value(forHTTPHeaderField: "X-Callback-Url") == "https://example.com/callback")
    #expect(try collectionBody(requests[2])["externalId"] as? String == "cancel-order")
}

@Test func collectionsPreapprovalV2AndSeparateMandateStatus() async throws {
    let transport = CollectionTransport([.init(code: 202, body: ""), .init(code: 200, body: #"{"status":"SUCCESSFUL","expirationDateTime":"2026-12-01T00:00:00Z"}"#), .init(code: 200, body: #"[{"preApprovalId":"system-mandate","toFri":"to","fromFri":"from","fromCurrency":"EUR","createdTime":"time","status":"APPROVED","message":"approved"}]"#), .init(code: 200, body: "")])
    let client = collectionClient(transport)
    let id = try await client.requestPreApproval(payload: .init(payer: collectionParty, payerCurrency: "EUR", payerMessage: "Allow", validityTime: 60), referenceId: collectionReference)
    let status = try await client.getPreApprovalStatus(referenceId: id)
    #expect(status.status == .successful)
    #expect(status.expirationDateTime == .text("2026-12-01T00:00:00Z"))
    let mandates = try await client.getPreApprovals(identity: .init(kind: .alias, value: "holder/alias"))
    #expect(mandates[0].status == .approved)
    try await client.cancelPreApproval(preApprovalId: mandates[0].preApprovalId)
    let requests = await transport.operations()
    #expect(requests[0].url!.path == "/collection/v2_0/preapproval")
    #expect(try collectionBody(requests[0])["validityTime"] as? Int == 60)
    #expect(requests[1].url!.path == "/collection/v2_0/preapproval/\(id)")
    #expect(requests[2].url!.absoluteString.contains("/collection/v1_0/preapprovals/alias/holder%2Falias") == true)
    #expect(requests[3].url!.path == "/collection/v1_0/preapproval/system-mandate")
    #expect(requests[3].httpMethod == "DELETE")
}

@Test func collectionsAccountFalseIdentityCasingAndCurrency() async throws {
    let transport = CollectionTransport([.init(code: 200, body: #"{"result":false}"#), .init(code: 200, body: "false"), .init(code: 404, body: #"{"code":"RESOURCE_NOT_FOUND"}"#), .init(code: 200, body: #"{"given_name":"Pat"}"#), .init(code: 200, body: #"{"availableBalance":"12","currency":"EUR"}"#)])
    let client = collectionClient(transport)
    #expect(try await !client.isAccountHolderActive(party: collectionParty))
    #expect(try await !client.isAccountHolderActive(party: collectionParty))
    #expect(try await !client.isAccountHolderActive(party: collectionParty))
    #expect(try await client.getBasicUserInfo(party: .init(partyIdType: .email, partyId: "a/b@example.com")).givenName == "Pat")
    #expect(try await client.getAccountBalance(currency: "EUR").currency == "EUR")
    let requests = await transport.operations()
    #expect(requests[0].url!.path == "/collection/v1_0/accountholder/msisdn/46700000000/active")
    #expect(requests[3].url!.absoluteString.contains("/Email/a%2Fb%40example.com/basicuserinfo") == true)
    #expect(requests[4].url!.path == "/collection/v1_0/account/balance/EUR")
}

@Test func collectionsWithdrawalVersionAndSparseUnknownPolling() async throws {
    let transport = CollectionTransport([.init(code: 202, body: ""), .init(code: 200, body: #"{"status":"NEW_SERVER_STATE"}"#), .init(code: 200, body: #"{"status":"FAILED","reason":{"code":"DECLINED"}}"#)])
    let client = collectionClient(transport)
    let id = try await client.requestToWithdraw(payload: .init(amount: "1", currency: "EUR", externalId: "order", payer: collectionParty, payerMessage: "Withdraw", payeeNote: "order"), referenceId: collectionReference, version: .v2)
    let result = try await client.waitForWithdrawal(referenceId: id, policy: .init(maxAttempts: 2, interval: 0, maximumInterval: 0))
    #expect(result.status == .failed)
    #expect(result.reason?.code == "DECLINED")
    let requests = await transport.operations()
    #expect(requests[0].url!.path == "/collection/v2_0/requesttowithdraw")
    #expect(requests[1].url!.path == "/collection/v1_0/requesttowithdraw/\(id)")
}

@Test func collectionsPaymentV2OptionalFieldsAndCreatedPolling() async throws {
    let transport = CollectionTransport([.init(code: 202, body: ""), .init(code: 200, body: #"{"status":"CREATED"}"#), .init(code: 200, body: #"{"status":"SUCCESSFUL","financialTransactionId":"tx"}"#)])
    let client = collectionClient(transport)
    let result = try await client.createPaymentAndWait(payload: .init(externalTransactionId: "order", money: .init(amount: "1", currency: "EUR"), customerReference: "customer", serviceProviderUserName: "utility", productId: "electricity", maxNumberOfRetries: 1, includeSenderCharges: false), policy: .init(maxAttempts: 2, interval: 0, maximumInterval: 0), referenceId: collectionReference)
    #expect(result.status == .successful)
    let requests = await transport.operations()
    #expect(requests[0].url!.path == "/collection/v2_0/payment")
    let body = try collectionBody(requests[0])
    #expect(body["externalTransactionId"] as? String == "order")
    #expect((body["money"] as? [String: String]) == ["amount": "1", "currency": "EUR"])
    #expect(body["includeSenderCharges"] as? Bool == false)
    #expect(body["couponId"] == nil)
    #expect(requests[1].url!.path == "/collection/v2_0/payment/abcdef12-3456-4789-abcd-012345678901")
}

@Test func collectionsInvalidPoliciesMakeNoRequestsAndExhaustionKeepsID() async throws {
    let empty = CollectionTransport([])
    let client = collectionClient(empty)
    do { _ = try await client.requestToPayAndWait(payload: collectionRequest, maxAttempts: 0); Issue.record("Invalid policy accepted") } catch { }
    #expect(await empty.allRequests().isEmpty)
    let transport = CollectionTransport([.init(code: 200, body: #"{"status":"UNKNOWN"}"#)])
    do { _ = try await collectionClient(transport).waitForRequestToPay(referenceId: "saved-id", policy: .init(maxAttempts: 1, interval: 0, maximumInterval: 0)); Issue.record("Unknown state completed") }
    catch let error as MoMoError { #expect(error.referenceId == "saved-id") }
}

@Test func collectionsSubmissionErrorRetainsIDAndNeverReplays() async throws {
    let transport = CollectionTransport([.init(code: 503, body: #"{"code":"UNAVAILABLE"}"#)])
    do { _ = try await collectionClient(transport).requestToPay(payload: collectionRequest, referenceId: collectionReference); Issue.record("Expected failure") }
    catch let error as MoMoError { #expect(error.referenceId == "abcdef12-3456-4789-abcd-012345678901"); #expect(error.statusCode == 503) }
    #expect(await transport.operations().count == 1)
}

@Test func collectionsModelForwardCompatibilityAndNumericExpiry() throws {
    let decoder = JSONDecoder()
    let mandate = try decoder.decode(ApprovedPreApproval.self, from: Data(#"{"preApprovalId":"id","toFri":"to","fromFri":"from","fromCurrency":"EUR","createdTime":"time","status":"FUTURE","message":"msg"}"#.utf8))
    #expect(mandate.status.rawValue == "FUTURE")
    let preapproval = try decoder.decode(PreApprovalStatus.self, from: Data(#"{"status":"PENDING","expirationDateTime":12}"#.utf8))
    #expect(preapproval.expirationDateTime == .integer(12))
    let payment = try decoder.decode(PaymentStatus.self, from: Data(#"{"status":"FUTURE"}"#.utf8))
    #expect(payment.status.rawValue == "FUTURE")
    #expect(!payment.status.isTerminal)
}

@Test func collectionsInvalidFinancialInputsNeverReachNetwork() async throws {
    let transport = CollectionTransport([])
    let client = collectionClient(transport)
    for (amount, currency, party, callback) in [
        ("-1", "EUR", collectionParty, nil as String?),
        ("1e2", "EUR", collectionParty, nil),
        ("1", "eur", collectionParty, nil),
        ("1", "EUR", Party(partyIdType: .msisdn, partyId: " "), nil),
        ("1", "EUR", collectionParty, "http://example.com/callback")
    ] {
        do {
            _ = try await client.requestToPay(payload: .init(amount: amount, currency: currency, externalId: "order", payer: party, payerMessage: "Order", payeeNote: "Order"), callbackURL: callback)
            Issue.record("Expected validation failure")
        } catch is MoMoError {}
    }
    #expect(await transport.allRequests().isEmpty)
}

@Test func collectionsAggregatorRoutingStaysInPayload() async throws {
    let transport = CollectionTransport([.init(code: 202, body: "")])
    let client = collectionClient(transport)
    _ = try await client.requestToPay(payload: .init(amount: "1.00", currency: "EUR", externalId: "order", payer: collectionParty, payerMessage: "Order", payeeNote: "Order", transferType: "CONTRACT_ROUTING"))
    let requests = await transport.operations()
    #expect(try collectionBody(requests[0])["transferType"] as? String == "CONTRACT_ROUTING")
    #expect(requests[0].value(forHTTPHeaderField: "transferType") == nil)
}

@Test func collectionsAccountRejectsUnsupportedAndEmptyIdentity() async throws {
    let transport = CollectionTransport([])
    let client = collectionClient(transport)
    await #expect(throws: CollectionValidationError.self) {
        _ = try await client.isAccountHolderActive(party: Party(partyIdType: .partyCode, partyId: "code"))
    }
    await #expect(throws: MoMoError.self) {
        _ = try await client.getBasicUserInfo(identity: .init(kind: .alias, value: " "))
    }
    await #expect(throws: MoMoError.self) { _ = try await client.getAccountBalance(currency: "eur") }
    #expect(await transport.allRequests().isEmpty)
}
