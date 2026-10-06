import Foundation

public struct MoMoPollingPolicy: Sendable {
    public let maxAttempts: Int
    public let interval: TimeInterval
    public let backoffMultiplier: Double
    public let maximumInterval: TimeInterval
    public init(maxAttempts: Int = 30, interval: TimeInterval = 2, backoffMultiplier: Double = 1.5, maximumInterval: TimeInterval = 30) {
        self.maxAttempts = maxAttempts; self.interval = interval; self.backoffMultiplier = backoffMultiplier; self.maximumInterval = maximumInterval
    }
    public func validate() throws {
        guard (1...10_000).contains(maxAttempts), interval.isFinite, interval >= 0,
              backoffMultiplier.isFinite, backoffMultiplier >= 1, maximumInterval.isFinite,
              maximumInterval >= interval, maximumInterval <= 86_400 else { throw MoMoError.invalidConfiguration("Invalid polling policy") }
    }
}
public enum MoMoPoller {
    public static func poll<T: Sendable>(referenceId: String, policy: MoMoPollingPolicy = .init(), operation: @Sendable () async throws -> T, isComplete: @Sendable (T) -> Bool) async throws -> T {
        try policy.validate()
        do {
        var delay = policy.interval
        for attempt in 0..<policy.maxAttempts {
            try Task.checkCancellation()
            let value: T
            do { value = try await operation() }
            catch is CancellationError { throw CancellationError() }
            catch { throw MoMoError.transactionFailure(referenceId: referenceId, underlying: error) }
            try Task.checkCancellation()
            if isComplete(value) { return value }
            if attempt + 1 < policy.maxAttempts {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                delay = min(policy.maximumInterval, delay * policy.backoffMultiplier)
            }
        }
        throw MoMoError.pollingExhausted(referenceId: referenceId)
        } catch is CancellationError {
            throw MoMoError.transactionFailure(referenceId: referenceId, underlying: CancellationError())
        }
    }
}
