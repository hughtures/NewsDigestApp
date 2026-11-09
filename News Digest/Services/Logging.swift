import Foundation
import os

/// Central place for the app's `os.Logger` instances.
///
/// View output live with:
/// `log stream --predicate 'subsystem == "com.hughy.News-Digest"' --level debug`
nonisolated enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.hughy.News-Digest"

    static let feeds = Logger(subsystem: subsystem, category: "feeds")
    static let api = Logger(subsystem: subsystem, category: "api")
    static let digest = Logger(subsystem: subsystem, category: "digest")
    static let storage = Logger(subsystem: subsystem, category: "storage")
    static let scheduler = Logger(subsystem: subsystem, category: "scheduler")
}
