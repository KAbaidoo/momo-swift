import Foundation
import MoMoCore

extension MoMoCollectionClient {
    public func createInvoice(payload: InvoiceRequest, referenceId: UUID = UUID(), callbackURL: String? = nil) async throws -> String {
        try CollectionValidation.money(payload.amount, payload.currency)
        try CollectionValidation.party(payload.intendedPayer)
        try CollectionValidation.party(payload.payee)
        try MoMoValidation.callbackURL(callbackURL)
        try MoMoValidation.referenceId(referenceId.uuidString)
        guard let seconds = Double(payload.validityDuration), seconds.isFinite, seconds > 0 else { throw CollectionValidationError.invalidValidity }
        let id = referenceId.uuidString.lowercased()
        return try await submit(InvoiceEndpoint.create(referenceId: id, payload: payload, callbackURL: callbackURL), referenceId: id)
    }
    public func getInvoiceStatus(referenceId: String) async throws -> InvoiceStatus {
        try await client.executeAuthenticated(InvoiceEndpoint.status(referenceId: referenceId), responseType: InvoiceStatus.self, tokenProvider: tokenProvider)
    }
    /// Cancellation requires its own reference ID and an external reconciliation ID.
    @discardableResult
    public func cancelInvoice(invoiceReferenceId: String, externalId: String, referenceId: UUID = UUID(), callbackURL: String? = nil) async throws -> String {
        try MoMoValidation.referenceId(referenceId.uuidString)
        try MoMoValidation.referenceId(invoiceReferenceId)
        try MoMoValidation.callbackURL(callbackURL)
        guard !externalId.isEmpty else { throw MoMoError.invalidConfiguration("External ID is required") }
        let id = referenceId.uuidString.lowercased()
        return try await submit(InvoiceEndpoint.cancel(invoiceReferenceId: invoiceReferenceId, referenceId: id, payload: .init(externalId: externalId), callbackURL: callbackURL), referenceId: id)
    }
}
