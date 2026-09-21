//
//  VoucherEndpoint.swift
//  MoMoSDK
//
//  Created by kobby on 15/09/2026.
//
import Foundation
import MoMoCore

enum VoucherEndpoint: MoMoEndpoint {
    case create(referenceId: String, payload: VoucherRequest, callbackURL: String?)
    case status(referenceId: String)
    case cancel(referenceId: String)
    
    var path: String {
        switch self {
        case .create:
            return "/collection/v1_0/voucher"
        case .status(let referenceId), .cancel(let referenceId):
            return "/collection/v1_0/voucher/\(referenceId)"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .create: return .post
        case .status: return .get
        case .cancel: return .delete
        }
    }
    
    var additionalHeaders: [String : String]? {
        switch self {
        case .create(let referenceId, _, let callbackURL):
            var headers = ["X-Reference-Id": referenceId]
            if let callbackURL {
                headers["X-Callback-Url"] = callbackURL
            }
            return headers
        case .status, .cancel:
            return nil
        }
    }
    
    func body() throws -> Data? {
        switch self {
        case .create(_, let payload, _):
            return try JSONEncoder().encode(payload)
        case .status, .cancel:
            return nil
        }
    }
}


