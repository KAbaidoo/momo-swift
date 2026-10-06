import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
import MoMoCore
import MoMoRemittance

private actor RemittanceTransport: MoMoHTTPTransport {
    var requests: [URLRequest] = []
    let result: String
    init(result: String = #"{"status":"SUCCESSFUL","reason":"completed"}"#) { self.result = result }
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let isToken = request.url!.absoluteString.hasSuffix("/remittance/token/")
        let body = isToken ? #"{"access_token":"remittance-token","token_type":"Bearer","expires_in":3600}"# : (request.httpMethod == "POST" ? "" : result)
        return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: isToken || request.httpMethod == "GET" ? 200 : 202, httpVersion: nil, headerFields: nil)!)
    }
}
private let remittanceCredentials = MoMoCredentials(apiUser: "r-user", apiKey: "r-key", subscriptionKey: "r-subscription")
private let remittanceParty = Party(partyIdType: .msisdn, partyId: "233240000000")

@Test func remittanceCashContractAndMetadata() async throws {
    let transport = RemittanceTransport()
    let client = MoMoRemittanceClient(credentials: remittanceCredentials, environment: .sandbox, transport: transport)
    let payload = CashTransferRequest(amount: "125.0001", currency: "GHS", payee: remittanceParty, externalId: "remit-1", originatingCountry: "GB", originalAmount: "8.45", originalCurrency: "GBP", payerMessage: "remittance", payeeNote: "family", payerIdentificationType: "PASS", payerIdentificationNumber: "passport", payerIdentity: "identity", payerFirstName: "Ada", payerSurname: "Lovelace", payerLanguageCode: "en", payerEmail: "ada@example.com", payerMsisdn: "447700900000", payerGender: "F")
    let reference = UUID()
    let result = try await client.cashTransferAndWait(payload: payload, referenceId: reference, policy: .init(maxAttempts: 1, interval: 0))
    #expect(result.reason == "completed")
    let requests = await transport.requests
    #expect(requests[0].url?.absoluteString.hasSuffix("/remittance/token/") == true)
    #expect(requests[0].value(forHTTPHeaderField: "Ocp-Apim-Subscription-Key") == "r-subscription")
    #expect(requests[1].url?.path == "/remittance/v2_0/cashtransfer")
    #expect(requests[2].url?.path == "/remittance/v2_0/cashtransfer/\(reference.uuidString.lowercased())")
    let body = try JSONSerialization.jsonObject(with: requests[1].httpBody!) as! [String: Any]
    #expect(body["orginatingCountry"] as? String == "GB")
    #expect(body["originatingCountry"] == nil)
    #expect(body["payerSurName"] as? String == "Lovelace")
    #expect(body["payerSurname"] == nil)
    #expect(body["amount"] as? String == "125.0001")
    #expect(body["originalAmount"] as? String == "8.45")
    #expect(body.count == 18)
}
@Test func remittanceTransferFailedTransactionReturnsStatus() async throws {
    let transport = RemittanceTransport(result: #"{"status":"FAILED","reason":{"code":"NOT_FOUND"}}"#)
    let client = MoMoRemittanceClient(credentials: remittanceCredentials, environment: .sandbox, transport: transport)
    let status = try await client.transferAndWait(payload: RemittanceTransferRequest(amount: "1", currency: "EUR", payee: remittanceParty), policy: .init(maxAttempts: 1, interval: 0))
    #expect(status.status == .failed)
    #expect(status.reason?.code == "NOT_FOUND")
    let requests = await transport.requests
    #expect(requests[1].url?.path == "/remittance/v1_0/transfer")
    #expect(requests[2].url?.path.hasPrefix("/remittance/v1_0/transfer/") == true)
}
@Test func remittanceAccountsAndNegativeValidation() async throws {
    let transport = RemittanceTransport(result: "false")
    let client = MoMoRemittanceClient(credentials: remittanceCredentials, environment: .sandbox, transport: transport)
    #expect(try await client.isAccountHolderActive(party: remittanceParty) == false)
    await #expect(throws: MoMoError.self) { try await client.cashTransferAndWait(payload: CashTransferRequest(amount: "1", currency: "EUR", payee: remittanceParty), policy: .init(maxAttempts: 0)) }
    await #expect(throws: MoMoError.self) { try await client.cashTransfer(payload: CashTransferRequest(amount: "1", currency: "EUR", payee: remittanceParty, originalAmount: "-1")) }
    await #expect(throws: MoMoError.self) { try await client.getCashTransferStatus(referenceId: "not-a-uuid") }
    #expect(await transport.requests.count == 2)
    let basicTransport = RemittanceTransport(result: #"{"family_name":"Smith"}"#)
    let basicClient = MoMoRemittanceClient(credentials: remittanceCredentials, environment: .sandbox, transport: basicTransport)
    #expect(try await basicClient.getBasicUserInfo(msisdn: "233240000000").familyName == "Smith")
    #expect(await basicTransport.requests.last?.url?.path == "/remittance/v1_0/accountholder/msisdn/233240000000/basicuserinfo")
    let balanceTransport = RemittanceTransport(result: #"{"availableBalance":"1.5","currency":"EUR"}"#)
    let balanceClient = MoMoRemittanceClient(credentials: remittanceCredentials, environment: .sandbox, transport: balanceTransport)
    _ = try await balanceClient.getAccountBalance(currency: "EUR")
    #expect(await balanceTransport.requests.last?.url?.path == "/remittance/v1_0/account/balance/EUR")
}
