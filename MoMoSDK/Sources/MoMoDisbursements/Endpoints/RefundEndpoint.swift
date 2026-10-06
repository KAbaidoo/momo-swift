import Foundation
import MoMoCore

enum RefundEndpoint: MoMoEndpoint {
    case initiate(referenceId: String, payload: RefundRequest, callbackURL: String?, version: DisbursementAPIVersion)
    case status(referenceId: String)
    var path: String {
        switch self {
        case .initiate(_, _, _, let version): return "/disbursement/\(version.rawValue)/refund"
        case .status(let id): return "/disbursement/v1_0/refund/\(MoMoPath.segment(id))"
        }
    }
    var method: HTTPMethod { if case .initiate = self { return .post }; return .get }
    var additionalHeaders: [String: String]? {
        if case .initiate(let id, _, let callback, _) = self {
            var headers = ["X-Reference-Id": id]
            if let callback { headers["X-Callback-Url"] = callback }
            return headers
        }
        return nil
    }
    func body() throws -> Data? {
        if case .initiate(_, let payload, _, _) = self { return try JSONEncoder().encode(payload) }
        return nil
    }
}
