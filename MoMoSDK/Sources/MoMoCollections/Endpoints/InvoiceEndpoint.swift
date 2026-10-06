import Foundation
import MoMoCore

enum InvoiceEndpoint: MoMoEndpoint {
    case create(referenceId: String, payload: InvoiceRequest, callbackURL: String?)
    case status(referenceId: String)
    case cancel(invoiceReferenceId: String, referenceId: String, payload: InvoiceCancellationRequest, callbackURL: String?)
    var path: String {
        switch self {
        case .create: return "/collection/v2_0/invoice"
        case .status(let id): return "/collection/v2_0/invoice/\(MoMoPath.segment(id))"
        case .cancel(let id, _, _, _): return "/collection/v2_0/invoice/\(MoMoPath.segment(id))"
        }
    }
    var method: HTTPMethod { switch self { case .create: .post; case .status: .get; case .cancel: .delete } }
    var additionalHeaders: [String: String]? {
        switch self {
        case .create(let id, _, let callback), .cancel(_, let id, _, let callback):
            var h = ["X-Reference-Id": id]
            h["X-Callback-Url"] = callback
            return h
        case .status: return nil
        }
    }
    func body() throws -> Data? {
        switch self {
        case .create(_, let payload, _): return try JSONEncoder().encode(payload)
        case .cancel(_, _, let payload, _): return try JSONEncoder().encode(payload)
        case .status: return nil
        }
    }
}
