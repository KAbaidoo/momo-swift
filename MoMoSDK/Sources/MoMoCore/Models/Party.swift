//
//  Party.swift
//  MoMoSDK
//
//  Created by kobby on 06/09/2026.
//
import Foundation

public struct Party: Codable, Sendable, Equatable {
    
    public enum PartyIDType: String, Codable, Sendable{
        case msisdn = "MSISDN"
        case email = "EMAIL"
        case partyCode = "PARTY_CODE"
    }
    
    public let partyIdType: PartyIDType
    public let partyId: String
    
    public init (partyIdType: PartyIDType, partyId: String) {
        self.partyIdType = partyIdType
        self.partyId = partyId
    }
    
}

