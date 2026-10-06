import Foundation

/// Sandbox-only settings supplied in the Xcode scheme's Run environment.
/// Production integrations should keep wallet credentials on a trusted backend.
enum DemoConfiguration {
    static var collectionSubscriptionKey: String {
        ProcessInfo.processInfo.environment["MOMO_COLLECTION_SUBSCRIPTION_KEY"] ?? ""
    }

    static var disbursementSubscriptionKey: String {
        ProcessInfo.processInfo.environment["MOMO_DISBURSEMENT_SUBSCRIPTION_KEY"] ?? ""
    }

    static var hasSubscriptionKeys: Bool {
        !collectionSubscriptionKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !disbursementSubscriptionKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
