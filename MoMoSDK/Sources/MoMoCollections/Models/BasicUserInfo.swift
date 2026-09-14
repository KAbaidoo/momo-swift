//
//  BasicUserInfo.swift
//  MoMoSDK
//
//  Created by kobby on 14/09/2026.
//

import Foundation

/// Represents the basic KYC information of a MoMo user.
public struct BasicUserInfo: Codable, Sendable, Equatable {
    public let givenName: String?
    public let familyName: String?
    public let birthdate: String?
    public let locale: String?
    public let gender: String?
    
    enum CodingKeys: String, CodingKey {
        case givenName = "given_name"
        case familyName = "family_name"
        case birthdate
        case locale
        case gender
    }

}
