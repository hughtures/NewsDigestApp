import Testing
import Foundation
@testable import News_Digest

@MainActor
struct SchedulerTests {
    var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }

    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    @Test func firesLaterTodayWhenTimeHasNotPassed() {
        let next = SchedulerService.nextFireDate(after: date(2026, 11, 9, 5, 0), time: DateComponents(hour: 6, minute: 30), calendar: calendar)
        #expect(next == date(2026, 11, 9, 6, 30))
    }

    @Test func rollsToTomorrowWhenTimeHasPassed() {
        let next = SchedulerService.nextFireDate(after: date(2026, 11, 9, 7, 0), time: DateComponents(hour: 6, minute: 30), calendar: calendar)
        #expect(next == date(2026, 11, 10, 6, 30))
    }

    @Test func exactlyAtFireTimeSchedulesTomorrow() {
        let next = SchedulerService.nextFireDate(after: date(2026, 11, 9, 6, 30), time: DateComponents(hour: 6, minute: 30), calendar: calendar)
        #expect(next == date(2026, 11, 10, 6, 30))
    }

    @Test func defaultsToSixAMWhenComponentsMissing() {
        let next = SchedulerService.nextFireDate(after: date(2026, 11, 9, 0, 0), time: DateComponents(), calendar: calendar)
        #expect(next == date(2026, 11, 9, 6, 0))
    }

    @Test func crossesDaylightSavingBoundary() {
        // US clocks fall back on 2026-11-01; a 6:00 AM schedule must stay 6:00 AM local.
        let next = SchedulerService.nextFireDate(after: date(2026, 10, 31, 12, 0), time: DateComponents(hour: 6, minute: 0), calendar: calendar)
        #expect(next == date(2026, 11, 1, 6, 0))
        #expect(calendar.dateComponents([.hour], from: next!).hour == 6)
    }
}

@MainActor
struct RetryTests {
    struct Boom: Error {}
    struct Fatal: Error {}

    final class Counter { var value = 0 }

    @Test func returnsImmediatelyOnSuccess() async throws {
        let calls = Counter()
        let result = try await withRetry(delay: 0) { calls.value += 1; return 42 }
        #expect(result == 42)
        #expect(calls.value == 1)
    }

    @Test func retriesUntilSuccess() async throws {
        let calls = Counter()
        let result = try await withRetry(maxAttempts: 3, delay: 0) { () -> String in
            calls.value += 1
            if calls.value < 3 { throw Boom() }
            return "done"
        }
        #expect(result == "done")
        #expect(calls.value == 3)
    }

    @Test func givesUpAfterMaxAttempts() async {
        let calls = Counter()
        await #expect(throws: Boom.self) {
            try await withRetry(maxAttempts: 3, delay: 0) { () -> Int in calls.value += 1; throw Boom() }
        }
        #expect(calls.value == 3)
    }

    @Test func doesNotRetryWhenPredicateRejects() async {
        let calls = Counter()
        await #expect(throws: Fatal.self) {
            try await withRetry(maxAttempts: 5, delay: 0, shouldRetry: { $0 is Boom }) { () -> Int in calls.value += 1; throw Fatal() }
        }
        #expect(calls.value == 1)
    }
}
