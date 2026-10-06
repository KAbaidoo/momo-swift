//
//  WithdrawalEndpoint.swift
//  MoMoSDK
//
//  Created by kobby on 09/09/2026.
//

import Foundation
import MoMoCore

enum WithdrawalEndpoint: MoMoEndpoint {
    case initiate(referenceId: String, payload: RequestToWithdrawRequest, callbackURL: String?, version: WithdrawalVersion)
    case status(referenceId: String)
    
    
    var path: String {
        switch self {
        case .initiate(_, _, _, let version):
            return "/collection/\(version.rawValue)/requesttowithdraw"
        case .status(let referenceId):
            return "/collection/v1_0/requesttowithdraw/\(MoMoPath.segment(referenceId))"
            
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .initiate: return .post
        case .status: return .get
        }
    }
    
    var additionalHeaders: [String : String]? {
        switch self {
        case .initiate(let referenceId, _, let callbackURL, _):
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
        case .initiate(_,let payload,_,_):
            return try JSONEncoder().encode(payload)
        case .status:
            return nil
        }
    }
    
    
}
