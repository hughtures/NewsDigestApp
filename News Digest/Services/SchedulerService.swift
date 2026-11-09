import os
import Foundation
import AppKit
import Combine

/// Fires a callback once a day at a user-chosen wall-clock time.
///
/// The previous implementation used `NSBackgroundActivityScheduler` with a
/// 24-hour interval, which ignores the configured time entirely. This one
/// computes the next occurrence of the chosen hour/minute and sleeps until
/// then using `ContinuousClock`, which keeps counting while the Mac sleeps.
final class SchedulerService: ObservableObject {
    static let shared = SchedulerService()

    @Published private(set) var isScheduled = false

    private var task: Task<Void, Never>?
    private var wakeObserver: NSObjectProtocol?

    private init() {}

    /// The next moment strictly after `now` whose hour and minute match `time`.
    static func nextFireDate(after now: Date, time: DateComponents, calendar: Calendar = .current) -> Date? {
        var target = DateComponents()
        target.hour = time.hour ?? 6
        target.minute = time.minute ?? 0
        target.second = 0
        return calendar.nextDate(after: now, matching: target, matchingPolicy: .nextTime)
    }

    func scheduleDaily(at time: DateComponents, onGenerate: @escaping @Sendable () async -> Void) {
        cancelSchedule()
        isScheduled = true

        task = Task {
            while !Task.isCancelled {
                guard let next = Self.nextFireDate(after: Date(), time: time) else { return }
                Log.scheduler.info("Next digest scheduled for \(next.formatted(), privacy: .public)")

                do {
                    try await Task.sleep(until: .now + .seconds(next.timeIntervalSinceNow), clock: ContinuousClock())
                } catch {
                    return // cancelled
                }
                await onGenerate()
            }
        }

        // After the Mac wakes, the sleep deadline is stale on wall-clock terms;
        // restart the loop so it recalculates against the real current time.
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.scheduleDaily(at: time, onGenerate: onGenerate)
        }
    }

    func cancelSchedule() {
        task?.cancel()
        task = nil
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
            self.wakeObserver = nil
        }
        isScheduled = false
    }

    /// Applies the user's saved settings: schedules or cancels as appropriate.
    func apply(_ settings: AppSettings) {
        if settings.isScheduleEnabled {
            scheduleDaily(at: settings.scheduleTime) {
                await DigestViewModel.shared.generateDigest()
            }
        } else {
            cancelSchedule()
        }
    }
}
