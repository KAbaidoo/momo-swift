import Foundation

/// Preserves future MTN values. Only known completed states stop transaction polling.
public enum TransactionStatus: RawRepresentable, Codable, Sendable, Equatable, Hashable {
    case pending, successful, failed, unknown(String)
    public init(rawValue: String) {
        switch rawValue { case "PENDING": self = .pending; case "SUCCESSFUL": self = .successful; case "FAILED": self = .failed; default: self = .unknown(rawValue) }
    }
    public var rawValue: String {
        switch self { case .pending: return "PENDING"; case .successful: return "SUCCESSFUL"; case .failed: return "FAILED"; case .unknown(let value): return value }
    }
    public var isTerminal: Bool { self == .successful || self == .failed }
    public init(from decoder: any Decoder) throws { self.init(rawValue: try decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: any Encoder) throws { var container = encoder.singleValueContainer(); try container.encode(rawValue) }
}
