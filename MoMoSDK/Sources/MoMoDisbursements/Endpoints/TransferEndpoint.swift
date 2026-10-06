import Foundation
import MoMoCore

enum TransferEndpoint: MoMoEndpoint {
    case initiate(referenceId: String, payload: TransferRequest, callbackURL: String?)
    case status(referenceId: String)
    var path: String {
        switch self {
        case .initiate(_, _, _): return "/disbursement/\("v1_0")/transfer"
        case .status(let id): return "/disbursement/v1_0/transfer/\(MoMoPath.segment(id))"
        }
    }
    var method: HTTPMethod { if case .initiate = self { return .post }; return .get }
    var additionalHeaders: [String: String]? {
        if case .initiate(let id, _, let callback) = self {
            var headers = ["X-Reference-Id": id]
            if let callback { headers["X-Callback-Url"] = callback }
            return headers
        }
        return nil
    }
    func body() throws -> Data? {
        if case .initiate(_, let payload, _) = self { return try JSONEncoder().encode(payload) }
        return nil
    }
}
