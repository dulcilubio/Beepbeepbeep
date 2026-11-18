import XCTest
@testable import startclock

/// The rules that decide when a start is signalled.
final class StartScheduleTests: XCTestCase {

    private func entry(_ hhmmss: String, name: String = "Runner", className: String = "H21") -> StartEntry {
        let parts = hhmmss.split(separator: ":").map { Int($0)! }
        let seconds = parts[0] * 3600 + parts[1] * 60 + (parts.count > 2 ? parts[2] : 0)
        var e = StartEntry(name: name, club: nil, start: seconds * 100, startnumber: nil)
        e.className = className
        return e
    }

    private func secs(_ hhmmss: String) -> Int {
        let parts = hhmmss.split(separator: ":").map { Int($0)! }
        return parts[0] * 3600 + parts[1] * 60 + (parts.count > 2 ? parts[2] : 0)
    }

    // MARK: - Windows

    func testWindowsSplitEntriesAroundTheCurrentInterval() {
        let entries = ["09:59:00", "10:00:00", "10:00:30", "10:01:00"].map { entry($0) }
        let w = StartSchedule.windows(entries: entries, secondsFromMidnight: secs("10:00:15"), interval: 60)

        XCTAssertEqual(w.previous.count, 1)
        XCTAssertEqual(w.current.count, 2)   // 10:00:00 and 10:00:30
        XCTAssertEqual(w.next.count, 1)
    }

    func testStartExactlyOnTheBoundaryBelongsToTheNewWindow() {
        let entries = [entry("10:01:00")]
        let w = StartSchedule.windows(entries: entries, secondsFromMidnight: secs("10:01:00"), interval: 60)
        XCTAssertEqual(w.current.count, 1)
        XCTAssertTrue(w.previous.isEmpty)
    }

    func testAutoModeUsesWholeMinuteWindows() {
        let entries = [entry("10:00:00"), entry("10:01:00")]
        let w = StartSchedule.windows(entries: entries, secondsFromMidnight: secs("10:00:40"), interval: 0)
        XCTAssertEqual(w.current.count, 1)
        XCTAssertEqual(w.next.count, 1)
    }

    func testEmptyListProducesEmptyWindows() {
        let w = StartSchedule.windows(entries: [], secondsFromMidnight: secs("10:00:00"), interval: 60)
        XCTAssertTrue(w.previous.isEmpty && w.current.isEmpty && w.next.isEmpty)
    }

    // MARK: - Highlight, fixed interval

    func testFixedIntervalGoesGreenOnTheInterval() {
        XCTAssertEqual(
            StartSchedule.highlight(entries: [], secondsFromMidnight: 0, epochSeconds: 1_800_000_060, interval: 60),
            .go
        )
    }

    func testFixedIntervalWarnsForTheLastFiveSeconds() {
        for remaining in 1...5 {
            let epoch = 1_800_000_060 - remaining
            XCTAssertEqual(
                StartSchedule.highlight(entries: [], secondsFromMidnight: 0, epochSeconds: epoch, interval: 60),
                .warning,
                "expected warning \(remaining) s before the start"
            )
        }
        XCTAssertEqual(
            StartSchedule.highlight(entries: [], secondsFromMidnight: 0, epochSeconds: 1_800_000_054, interval: 60),
            .none
        )
    }

    // MARK: - Highlight, auto mode

    func testAutoModeGoesGreenOnAListedStart() {
        let entries = [entry("10:00:00")]
        XCTAssertEqual(
            StartSchedule.highlight(entries: entries, secondsFromMidnight: secs("10:00:00"), epochSeconds: 0, interval: 0),
            .go
        )
    }

    func testAutoModeWarnsFiveSecondsBefore() {
        let entries = [entry("10:00:00")]
        XCTAssertEqual(
            StartSchedule.highlight(entries: entries, secondsFromMidnight: secs("09:59:56"), epochSeconds: 0, interval: 0),
            .warning
        )
        XCTAssertEqual(
            StartSchedule.highlight(entries: entries, secondsFromMidnight: secs("09:59:54"), epochSeconds: 0, interval: 0),
            .none
        )
    }

    /// Regression: a runner starting on this very second must win over the
    /// countdown for a runner a few seconds out, whatever the list order.
    func testStartOnThisSecondOutranksACountdownLaterInTheList() {
        let entries = [entry("10:00:03", name: "Later"), entry("10:00:00", name: "Now")]
        XCTAssertEqual(
            StartSchedule.highlight(entries: entries, secondsFromMidnight: secs("10:00:00"), epochSeconds: 0, interval: 0),
            .go
        )
    }

    func testAutoModeIsSilentWithoutAList() {
        XCTAssertEqual(
            StartSchedule.highlight(entries: [], secondsFromMidnight: secs("10:00:00"), epochSeconds: 0, interval: 0),
            .none
        )
    }
}
