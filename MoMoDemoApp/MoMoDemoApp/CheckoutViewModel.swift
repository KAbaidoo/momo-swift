import Foundation
import Combine
import MoMoCore
import MoMoCollections

@MainActor
class CheckoutViewModel: ObservableObject {
    @Published var transactionStatus = "Idle"
    @Published var isProcessing = false
    @Published private(set) var referenceId: String?
    @Published private(set) var hasUnresolvedRequest = false
    let client: MoMoCollectionClient
    private let defaults: UserDefaults
    private let referenceStorageKey = "momo.demo.collection.reference"

    init(client: MoMoCollectionClient, defaults: UserDefaults = .standard) {
        self.client = client
        self.defaults = defaults
        referenceId = defaults.string(forKey: referenceStorageKey)
        hasUnresolvedRequest = referenceId != nil && (defaults.object(forKey: referenceStorageKey + ".unresolved") as? Bool ?? true)
        if let referenceId {
            transactionStatus = "Previous request: \(referenceId). Check its status before making another payment."
        }
    }

    func simulatePurchase(phoneNumber: String, amount: String, currency: String, payerMessage: String, payeeNote: String, deliveryNote: String) async {
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
        transactionStatus = "Requesting payment approval..."
        let id = UUID()
        referenceId = id.uuidString.lowercased()
        // Persist before submission: loss of the HTTP response is not proof of failure.
        defaults.set(referenceId, forKey: referenceStorageKey)
        hasUnresolvedRequest = true
        defaults.set(true, forKey: referenceStorageKey + ".unresolved")
        let payload = RequestToPayRequest(amount: amount, currency: currency,
            externalId: id.uuidString.lowercased(), payer: Party(partyIdType: .msisdn, partyId: phoneNumber),
            payerMessage: payerMessage, payeeNote: payeeNote)
        do {
            _ = try await client.requestToPay(payload: payload, referenceId: id)
        } catch {
            if (error as? MoMoError)?.isKnownPreSubmissionFailure == true {
                clearUnsentRequest()
                transactionStatus = "Request was not sent. You can try again."
            } else {
                showUncertainOutcome(error)
            }
            return
        }

        transactionStatus = "Awaiting payment approval... Reference: \(referenceId ?? "")"
        let status: RequestToPayStatus
        do { status = try await waitForResult(referenceId: id.uuidString.lowercased()) }
        catch {
            showUncertainOutcome(error)
            return
        }
        show(status)
        if status.status == .successful, !deliveryNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            do { try await client.sendDeliveryNotification(for: id.uuidString.lowercased(), message: deliveryNote) }
            catch { transactionStatus += " Payment succeeded; the delivery notification was not confirmed." }
        }
    }

    func checkExistingRequest() async {
        guard !isProcessing, let referenceId else { return }
        isProcessing = true
        defer { isProcessing = false }
        transactionStatus = "Checking existing payment... Reference: \(referenceId)"
        do { show(try await waitForResult(referenceId: referenceId)) }
        catch { showUncertainOutcome(error) }
    }

    private func waitForResult(referenceId: String) async throws -> RequestToPayStatus {
        try await MoMoPoller.poll(referenceId: referenceId, policy: MoMoPollingPolicy(),
            operation: { [client] in try await client.getTransactionStatus(referenceId: referenceId) },
            isComplete: { $0.status.isTerminal })
    }

    private func show(_ result: RequestToPayStatus) {
        hasUnresolvedRequest = false
        defaults.set(false, forKey: referenceStorageKey + ".unresolved")
        if result.status == .successful {
            transactionStatus = "Success! Reference: \(referenceId ?? "")"
        } else {
            transactionStatus = "Failed: \(result.reason?.message ?? "No failure message returned"). Reference: \(referenceId ?? "")"
        }
    }

    private func showUncertainOutcome(_ error: Error) {
        if error is CancellationError || (error as? MoMoError)?.isCancellation == true {
            transactionStatus = "Stopped waiting. The payment may still complete. Reference: \(referenceId ?? "")"
        } else {
            transactionStatus = "Status not confirmed: \(error.localizedDescription). Check this request before making another payment. Reference: \(referenceId ?? "")"
        }
    }

    private func clearUnsentRequest() {
        defaults.removeObject(forKey: referenceStorageKey)
        defaults.removeObject(forKey: referenceStorageKey + ".unresolved")
        referenceId = nil
        hasUnresolvedRequest = false
    }
}
