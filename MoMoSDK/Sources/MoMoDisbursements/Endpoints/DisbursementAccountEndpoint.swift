import MoMoCore

enum DisbursementAccountEndpoint: MoMoEndpoint {
    case getBalance(currency: String?)
    case validateAccountHolder(party: Party)
    case getBasicUserInfo(identity: DisbursementAccountIdentity)
    var path: String {
        switch self {
        case .getBalance(let currency): return "/disbursement/v1_0/account/balance" + (currency.map { "/" + MoMoPath.segment($0) } ?? "")
        case .validateAccountHolder(let party): return accountPath(party) + "/active"
        case .getBasicUserInfo(let identity): return "/disbursement/v1_0/accountholder/\(identity.kind.rawValue)/\(MoMoPath.segment(identity.value))/basicuserinfo"
        }
    }
    private func accountPath(_ party: Party) -> String { "/disbursement/v1_0/accountholder/\(party.partyIdType.rawValue.lowercased())/\(MoMoPath.segment(party.partyId))" }
    var method: HTTPMethod { .get }
}
