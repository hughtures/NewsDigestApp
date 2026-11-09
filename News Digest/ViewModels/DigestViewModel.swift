import Foundation
import SwiftUI
import Combine

@MainActor
final class DigestViewModel: ObservableObject {
    static let shared = DigestViewModel()

    @Published var currentDigest: NewsDigest?
    @Published var isLoading = false
    @Published var error: Error?

    private init() {
        loadLatestDigest()
    }

    /// Generates a digest and publishes the result. `isLoading` stays true for
    /// exactly as long as generation runs, and failures surface in `error`.
    func generateDigest() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            currentDigest = try await BackgroundDigestService.shared.generateDigest()
        } catch DigestError.alreadyRunning {
            // Another trigger is mid-flight; nothing to report.
        } catch {
            self.error = error
        }
    }

    func loadLatestDigest() {
        currentDigest = StorageService.shared.getLatestDigest()
    }

    func clearError() {
        error = nil
    }
}
