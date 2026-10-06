import Foundation
import MoMoCore

enum PaymentEndpoint: MoMoEndpoint {
    case create(referenceId: String, payload: PaymentRequest, callbackURL: String?)
    case status(referenceId: String)
    var path: String {
        switch self { case .create: "/collection/v2_0/payment"; case .status(let id): "/collection/v2_0/payment/\(MoMoPath.segment(id))" }
    }
    var method: HTTPMethod { switch self { case .create: .post; case .status: .get } }
    var additionalHeaders: [String: String]? {
        guard case .create(let id, _, let callback) = self else { return nil }
        var h = ["X-Reference-Id": id]; h["X-Callback-Url"] = callback; return h
    }
    func body() throws -> Data? {
        guard case .create(_, let payload, _) = self else { return nil }
        return try JSONEncoder().encode(payload)
    }
}
