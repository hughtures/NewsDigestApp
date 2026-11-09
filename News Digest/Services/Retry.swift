import os
import Foundation

/// Runs `operation`, retrying failures that `shouldRetry` approves of.
///
/// - Parameters:
///   - maxAttempts: Total attempts including the first one.
///   - delay: Seconds to wait between attempts (injectable so tests don't sleep).
nonisolated func withRetry<T>(
    maxAttempts: Int = 3,
    delay: TimeInterval = 5,
    shouldRetry: (Error) -> Bool = { _ in true },
    operation: () async throws -> T
) async throws -> T {
    var attempt = 1
    while true {
        do {
            return try await operation()
        } catch {
            guard attempt < maxAttempts, shouldRetry(error), !Task.isCancelled else {
                throw error
            }
            Log.digest.warning("Attempt \(attempt)/\(maxAttempts) failed: \(error.localizedDescription, privacy: .public). Retrying in \(delay, format: .fixed(precision: 0))s")
            if delay > 0 {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            attempt += 1
        }
    }
}
