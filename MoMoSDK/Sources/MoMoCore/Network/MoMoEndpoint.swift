//
//  MoMoEndpoint.swift
//  MoMoSDK
//
//  Created by kobby on 26/08/2026.
//

import Foundation

public protocol MoMoEndpoint: Sendable {
    var path: String { get }
    var method: HTTPMethod { get }
    var additionalHeaders: [String: String]? { get }
    
    func body() throws -> Data?
}

//Default implementation to make addoption easy
public extension MoMoEndpoint {
    var additionalHeaders: [String: String]? {
        return nil
    }
    
    func body() throws -> Data? {
        return nil
    }
    
}
