//
//  AccountEndpoint.swift
//  MoMoSDK
//
//  Created by kobby on 07/09/2026.
//

import Foundation
import MoMoCore

enum AccountEndpoint: MoMoEndpoint{
    case getBalance
    case validateAccountHolder(party: Party)
    
    var path: String {
        switch self {
        case .getBalance:
            return "/collection/v1_0/account/balance"
        case .validateAccountHolder(let party):
            let type = party.partyIdType.rawValue.lowercased()
            return "/collection/v1_0/accountholder/\(type)/\(party.partyId)/active"
        }
        
    }
    
    var method: MoMoCore.HTTPMethod {
        return .get
    }
    
}
