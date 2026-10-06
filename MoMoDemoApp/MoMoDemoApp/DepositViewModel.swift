import Foundation
import Combine
import MoMoCore
import MoMoDisbursements

@MainActor
class DepositViewModel: ObservableObject {
    @Published var transactionStatus = "Idle"
    @Published var isProcessing = false
    @Published private(set) var referenceId: String?
    @Published private(set) var hasUnresolvedRequest = false
    let client: MoMoDisbursementClient
    private let referenceStorageKey = "momo.demo.deposit.reference"

    init(client: MoMoDisbursementClient) {
        self.client = client
        referenceId = UserDefaults.standard.string(forKey: referenceStorageKey)
        hasUnresolvedRequest = referenceId != nil && (UserDefaults.standard.object(forKey: referenceStorageKey + ".unresolved") as? Bool ?? true)
        if let referenceId {
            transactionStatus = "Previous request: \(referenceId). Check its status before making another deposit."
        }
    }

    func simulateDeposit(phoneNumber: String, amount: String, currency: String, payerMessage: String, payeeNote: String) async {
        guard !isProcessing, !hasUnresolvedRequest else { return }
        do {
            try MoMoValidation.amount(amount)
            guard !phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, currency.range(of: "^[A-Z]{3}$", options: .regularExpression) != nil else {
                throw MoMoError.invalidConfiguration("Enter a phone number and three-letter currency")
            }
        } catch {
            transactionStatus = error.localizedDescription
            return
        }
        isProcessing = true
        defer { isProcessing = false }
        let id = UUID()
        referenceId = id.uuidString.lowercased()
        UserDefaults.standard.set(referenceId, forKey: referenceStorageKey)
        hasUnresolvedRequest = true
        UserDefaults.standard.set(true, forKey: referenceStorageKey + ".unresolved")
        transactionStatus = "Initiating deposit..."
        let payload = DepositRequest(amount: amount, currency: currency, externalId: id.uuidString.lowercased(),
            payee: Party(partyIdType: .msisdn, partyId: phoneNumber), payerMessage: payerMessage, payeeNote: payeeNote)
        do {
            _ = try await client.deposit(payload: payload, referenceId: id)
            transactionStatus = "Awaiting deposit result... Reference: \(referenceId ?? "")"
            show(try await waitForResult(referenceId: id.uuidString.lowercased()))
        } catch { showUncertainOutcome(error) }
    }

    func checkExistingRequest() async {
        guard !isProcessing, let referenceId else { return }
        isProcessing = true
        defer { isProcessing = false }
        transactionStatus = "Checking existing deposit... Reference: \(referenceId)"
        do { show(try await waitForResult(referenceId: referenceId)) }
        catch { showUncertainOutcome(error) }
    }

    private func waitForResult(referenceId: String) async throws -> DepositStatus {
        try await MoMoPoller.poll(referenceId: referenceId, policy: MoMoPollingPolicy(),
            operation: { [client] in try await client.getDepositStatus(referenceId: referenceId) },
            isComplete: { $0.status?.isTerminal == true })
    }

    private func show(_ result: DepositStatus) {
        hasUnresolvedRequest = false
        UserDefaults.standard.set(false, forKey: referenceStorageKey + ".unresolved")
        transactionStatus = result.status == .successful
            ? "Success! Reference: \(referenceId ?? "")"
            : "Failed: \(result.reason?.message ?? "No failure message returned"). Reference: \(referenceId ?? "")"
    }

    private func showUncertainOutcome(_ error: Error) {
        transactionStatus = error is CancellationError || (error as? MoMoError)?.isCancellation == true
            ? "Stopped waiting. The deposit may still complete. Reference: \(referenceId ?? "")"
            : "Status not confirmed: \(error.localizedDescription). Check this request before making another deposit. Reference: \(referenceId ?? "")"
    }
}
