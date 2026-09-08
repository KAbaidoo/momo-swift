//
//  PreApprovalEndpoint.swift
//  MoMoSDK
//
//  Created by kobby on 08/09/2026.
//

import Foundation
import MoMoCore

enum PreApprovalEndpoint: MoMoEndpoint {
    
    case initiate(referenceId: String, payload: PreApprovalRequest, callbackURL: String?)
    case status(referenceId: String)
    case list(party: Party)
    case cancel(referenceId: String)
    
    var path: String {
        switch self {
        case .initiate:
            return "/collection/v1_0/preapproval"
        case .status(let referenceId), .cancel(let referenceId):
            return "/collection/v1_0/preapproval/\(referenceId)"
        case .list(let party):
            let type = party.partyIdType.rawValue.lowercased()
            return "/collection/v1_0/preapprovals/\(type)/\(party.partyId)"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .initiate: return .post
        case .status, .list: return .get
        case .cancel: return .delete
        }
    }
    
    var additionalHeaders: [String : String]? {
        switch self {
        case .initiate(let referenceId, _, let callbackURL):
            var headers = ["X-Reference-Id": referenceId]
            if let callback = callbackURL {
                headers["X-Callback-Url"] = callback
            }
            return headers
        default:
            return nil
        }
    }
    
    func body() throws -> Data? {
        switch self {
        case .initiate(_, let payload, _):
            return try JSONEncoder().encode(payload)
        default:
            return nil
        }
    }
    
}
