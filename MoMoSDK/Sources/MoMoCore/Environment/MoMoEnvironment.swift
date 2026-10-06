//
//  MoMoEnvironment.swift
//  MoMoSDK
//
//  Created by kobby on 27/08/2026.
//

import Foundation

/// Defines the target environment and routing for the MTN MoMo API.
public enum MoMoEnvironment: Sendable, Hashable {
    
    /// The Sandbox environment used for development and testing
    case sandbox
    
    /// The live Production environment.
    /// - Parameters:
    ///     - targetEnvironment: The identifier for your specific regional operator (e.g "mtnghana", "mtnuganda").
    ///     - baseURL: The production base URL provided by MTN upon Go-Live approval.
    case production(targetEnvironment: String, baseURL: URL)
    
    /// The gateway base URL for all network requests.
    public var baseURL: URL {
        switch self {
        case .sandbox:
            // Standard MTN MoMo Sandbox gateway
            return URL(string: "https://sandbox.momodeveloper.mtn.com")!
        case .production(_, baseURL: let baseURL):
            return baseURL
        }
    }
    
    /// The value required for the 'X-Target-Environment' HTTP header.
    public var targetEnvironmentHeaderValue: String {
        switch self {
        case .sandbox:
            return "sandbox"
        case .production(targetEnvironment: let targetEnvironment,_):
            return targetEnvironment
        }
    }
    
    
    
}
