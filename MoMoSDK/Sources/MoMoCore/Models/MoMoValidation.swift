import Foundation

public enum MoMoValidation {
    public static func amount(_ value: String) throws {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...2).contains(parts.count), parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy({ $0 >= "0" && $0 <= "9" }) }), value.contains(where: { $0 >= "1" && $0 <= "9" }) else { throw MoMoError.invalidConfiguration("Amount must be a positive decimal string") }
    }
    public static func referenceId(_ value: String) throws {
        guard let uuid = UUID(uuidString: value), uuid.uuidString.split(separator: "-")[2].first == "4", let variant = uuid.uuidString.split(separator: "-")[3].first, "89AB".contains(variant) else { throw MoMoError.invalidConfiguration("Reference ID must be UUID version 4") }
    }
    public static func callbackURL(_ value: String?) throws {
        guard let value else { return }
        guard let url = URLComponents(string: value), url.scheme?.lowercased() == "https", url.host?.isEmpty == false, url.user == nil, url.password == nil, url.fragment == nil else { throw MoMoError.invalidConfiguration("Callback URL must be HTTPS with a valid host") }
    }
}
