//
//  RequestToPayEndpoint.swift
//  MoMoSDK
//
//  Created by kobby on 06/09/2026.
//


import Foundation
import MoMoCore

enum RequestToPayEndpoint: MoMoEndpoint {
    
    /// Initiates a new payment request.
    case initiate(referenceId: String, payload: RequestToPayRequest, callbackURL: String?)
    
    /// Checks the status of an existing request.
    case status(referenceId: String)
    
    var path: String {
        switch self {
        case .initiate:
            return "/collection/v1_0/requesttopay"
        case .status(let referenceId):
            return "/collection/v1_0/requesttopay/\(referenceId)"
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
            return nil // No extra headers needed for the GET request
        }
    }
    
    func body() throws -> Data? {
        switch self {
        case .initiate(_, let payload, _):
            let encoder = JSONEncoder()
            return try encoder.encode(payload)
        case .status:
            return nil
        }
    }
}