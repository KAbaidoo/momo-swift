//
//  DisbursementAccountEndpoint.swift
//  MoMoSDK
//
//  Created by kobby on 21/09/2026.
//


import Foundation
import MoMoCore

enum DisbursementAccountEndpoint: MoMoEndpoint {
    case getBalance
    case validateAccountHolder(party: Party)
    case getBasicUserInfo(party: Party)
    
    var path: String {
        switch self {
        case .getBalance:
            return "/disbursement/v1_0/account/balance"
        case .validateAccountHolder(let party):
            let type = party.partyIdType.rawValue.lowercased()
            return "/disbursement/v1_0/accountholder/\(type)/\(party.partyId)/active"
        case .getBasicUserInfo(let party):
            let type = party.partyIdType.rawValue.lowercased()
            return "/disbursement/v1_0/accountholder/\(type)/\(party.partyId)/basicuserinfo"
        }
    }
    
    var method: HTTPMethod {
        return .get
    }
}