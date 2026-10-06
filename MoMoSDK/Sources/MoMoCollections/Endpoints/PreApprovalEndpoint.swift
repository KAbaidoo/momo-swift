import Foundation
import MoMoCore

enum PreApprovalEndpoint: MoMoEndpoint {
    case initiate(referenceId: String, payload: PreApprovalRequest, callbackURL: String?)
    case status(referenceId: String)
    case list(identity: CollectionAccountIdentity)
    case cancel(preApprovalId: String)
    var path: String {
        switch self {
        case .initiate: return "/collection/v2_0/preapproval"
        case .status(let id): return "/collection/v2_0/preapproval/\(MoMoPath.segment(id))"
        case .cancel(let id): return "/collection/v1_0/preapproval/\(MoMoPath.segment(id))"
        case .list(let identity): return "/collection/v1_0/preapprovals/\(identity.kind.rawValue.lowercased())/\(MoMoPath.segment(identity.value))"
        }
    }
    var method: HTTPMethod { switch self { case .initiate: .post; case .status, .list: .get; case .cancel: .delete } }
    var additionalHeaders: [String: String]? {
        guard case .initiate(let id, _, let callback) = self else { return nil }
        var h = ["X-Reference-Id": id]; h["X-Callback-Url"] = callback; return h
    }
    func body() throws -> Data? {
        guard case .initiate(_, let payload, _) = self else { return nil }
        return try JSONEncoder().encode(payload)
    }
}
