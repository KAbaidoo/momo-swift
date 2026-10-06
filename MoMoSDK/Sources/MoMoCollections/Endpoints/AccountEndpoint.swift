import Foundation
import MoMoCore

enum AccountEndpoint: MoMoEndpoint {
    case getBalance
    case currencyBalance(String)
    case validateAccountHolder(party: Party)
    case getBasicUserInfo(identity: CollectionAccountIdentity)
    var path: String {
        switch self {
        case .getBalance: return "/collection/v1_0/account/balance"
        case .currencyBalance(let currency): return "/collection/v1_0/account/balance/\(MoMoPath.segment(currency))"
        case .validateAccountHolder(let party): return "/collection/v1_0/accountholder/\(party.partyIdType.rawValue.lowercased())/\(MoMoPath.segment(party.partyId))/active"
        case .getBasicUserInfo(let identity): return "/collection/v1_0/accountholder/\(identity.kind.rawValue)/\(MoMoPath.segment(identity.value))/basicuserinfo"
        }
    }
    var method: HTTPMethod { .get }
}
