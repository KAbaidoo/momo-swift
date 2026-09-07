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
    /// Notify service/product delivery
    case deliveryNotification(referenceId: String, payload: DeliveryNotification)
    
    var path: String {
        switch self {
        case .initiate:
            return "/collection/v1_0/requesttopay"
        case .status(let referenceId):
            return "/collection/v1_0/requesttopay/\(referenceId)"
        case .deliveryNotification(let referenceId,_):
            return "/collection/v1_0/requesttopay/\(referenceId)/deliverynotification"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .initiate, .deliveryNotification: return .post
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
            
        case .deliveryNotification:
            // Standard MoMo requirement for this endpoint
            return ["notificationMessage": "Delivery Confirmation"]
            
        case .status:
            return nil // No extra headers needed for the GET request
        }
    }
    
    func body() throws -> Data? {
        let encoder = JSONEncoder()
        switch self {
        case .initiate(_, let payload, _):
            return try encoder.encode(payload)
        case .deliveryNotification(_, let payload):
            return try encoder.encode(payload)
        case .status:
            return nil
        }
    }
}
