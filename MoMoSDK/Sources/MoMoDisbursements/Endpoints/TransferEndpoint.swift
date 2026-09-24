//
//  TransferEndpoint.swift
//  MoMoSDK
//
//  Created by kobby on 24/09/2026.
//

import Foundation
import MoMoCore

enum TransferEndpoint: MoMoEndpoint {
    case initiate(referenceId: String, payload: TransferRequest, callbackURL: String?)
    case status(referenceId: String)
    
    var path: String {
        switch self {
        case .initiate:
            return "/disbursement/v1_0/transfer"
        case .status(let referenceId):
            return "/disbursement/v1_0/transfer/\(referenceId)"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .initiate: return .post
        case .status: return .get
        }
    }
    
    var additionalHeaders: [String: String]? {
        switch self {
        case .initiate(let referenceId, _, let callbackURL):
            var headers = ["X-Reference-Id": referenceId]
            if let callback = callbackURL {
                headers["X-Callback-Url"] = callback
            }
            return headers
        case .status:
            return nil
        }
    }
    
    func body() throws -> Data? {
        switch self {
        case .initiate(_, let payload, _):
            return try JSONEncoder().encode(payload)
        case .status:
            return nil
        }
    }
    
}
