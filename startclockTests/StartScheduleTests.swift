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

/// What the participant banner shows, which depends on whether the clock is
/// already running ahead (lead time) or showing real time.
final class BannerContentTests: XCTestCase {

    private func entry(_ hhmmss: String, name: String) -> StartEntry {
        let parts = hhmmss.split(separator: ":").map { Int($0)! }
        let seconds = parts[0] * 3600 + parts[1] * 60 + (parts.count > 2 ? parts[2] : 0)
        var e = StartEntry(name: name, club: nil, start: seconds * 100, startnumber: nil)
        e.className = "H21"
        return e
    }

    private func secs(_ hhmmss: String) -> Int {
        let parts = hhmmss.split(separator: ":").map { Int($0)! }
        return parts[0] * 3600 + parts[1] * 60 + (parts.count > 2 ? parts[2] : 0)
    }

    private var startList: [StartEntry] {
        [entry("18:22:00", name: "Gone"),
         entry("18:23:00", name: "Next"),
         entry("18:24:00", name: "After")]
    }

    func testWithoutLeadTimeFocusMovesToTheNextGroupImmediately() {
        let banner = StartSchedule.banner(
            entries: startList, secondsFromMidnight: secs("18:22:01"),
            interval: 60, leadTimeEnabled: false
        )
        XCTAssertEqual(banner.current.map(\.name), ["Next"], "the runners still standing there")
        XCTAssertEqual(banner.next.map(\.name), ["After"])
        XCTAssertEqual(banner.departed.map(\.name), ["Gone"])
        XCTAssertGreaterThan(banner.departedOpacity, 0)
    }

    func testDepartedNamesFadeAndThenLeave() {
        func opacity(at time: String) -> Double {
            StartSchedule.banner(
                entries: startList, secondsFromMidnight: secs(time),
                interval: 60, leadTimeEnabled: false
            ).departedOpacity
        }

        let atStart = opacity(at: "18:22:00")
        let midway  = opacity(at: "18:22:04")
        XCTAssertGreaterThan(atStart, midway)
        XCTAssertGreaterThan(midway, 0)

        // Five seconds is the whole fade — by then the banner is theirs alone.
        let afterFade = StartSchedule.banner(
            entries: startList, secondsFromMidnight: secs("18:22:05"),
            interval: 60, leadTimeEnabled: false
        )
        XCTAssertEqual(afterFade.departedOpacity, 0, accuracy: 0.001)
        XCTAssertTrue(afterFade.departed.isEmpty, "faded rows must not keep taking up space")
        XCTAssertEqual(afterFade.current.map(\.name), ["Next"])
    }

    func testWithLeadTimeTheCalledGroupStaysInFocus() {
        // The clock already runs ahead, so 18:22 are the ones walking up now.
        let banner = StartSchedule.banner(
            entries: startList, secondsFromMidnight: secs("18:22:30"),
            interval: 60, leadTimeEnabled: true
        )
        XCTAssertEqual(banner.current.map(\.name), ["Gone"])
        XCTAssertEqual(banner.next.map(\.name), ["Next"])
        XCTAssertEqual(banner.departedOpacity, 0.38, accuracy: 0.001)
    }

    func testEmptyListGivesAnEmptyBanner() {
        let banner = StartSchedule.banner(
            entries: [], secondsFromMidnight: secs("18:22:01"),
            interval: 60, leadTimeEnabled: false
        )
        XCTAssertTrue(banner.isEmpty)
    }
}

/// Ordering inside a group, and what to drop when the names are scaled up.
final class BannerLayoutTests: XCTestCase {

    private func entry(_ hhmmss: String, name: String) -> StartEntry {
        let parts = hhmmss.split(separator: ":").map { Int($0)! }
        let seconds = parts[0] * 3600 + parts[1] * 60 + (parts.count > 2 ? parts[2] : 0)
        return StartEntry(name: name, club: nil, start: seconds * 100, startnumber: nil)
    }

    private func secs(_ hhmmss: String) -> Int {
        let parts = hhmmss.split(separator: ":").map { Int($0)! }
        return parts[0] * 3600 + parts[1] * 60 + (parts.count > 2 ? parts[2] : 0)
    }

    /// Eventor hands over page order, not start order. Seen at a start as
    /// 11:23:53 listed above 11:23:31.
    func testGroupsComeBackInStartOrderFromAnUnsortedSource() {
        let unsorted = [
            entry("11:23:53", name: "Cecilia"),
            entry("11:23:00", name: "Gabriel"),
            entry("11:23:31", name: "Robin"),
        ]
        let banner = StartSchedule.banner(
            entries: unsorted, secondsFromMidnight: secs("11:22:30"),
            interval: 60, leadTimeEnabled: false
        )
        XCTAssertEqual(banner.current.map(\.name), ["Gabriel", "Robin", "Cecilia"])
    }

    func testRunnersSharingAStartTimeAreOrderedByName() {
        let entries = [entry("11:23:00", name: "Bertil"), entry("11:23:00", name: "Anna")]
        let banner = StartSchedule.banner(
            entries: entries, secondsFromMidnight: secs("11:22:30"),
            interval: 60, leadTimeEnabled: false
        )
        XCTAssertEqual(banner.current.map(\.name), ["Anna", "Bertil"])
    }

    // MARK: - Row budget

    func testEverythingFitsWhenThereIsRoom() {
        let shown = StartSchedule.rowAllocation(fitting: 12, departed: 3, current: 6, next: 3)
        XCTAssertEqual(shown, .init(departed: 3, current: 6, next: 3, hiddenCurrent: 0))
    }

    func testTightSpaceGoesToTheRunnersWhoHaveNotStarted() {
        let shown = StartSchedule.rowAllocation(fitting: 4, departed: 3, current: 6, next: 3)
        XCTAssertEqual(shown.current, 4, "the group in focus takes the space first")
        XCTAssertEqual(shown.next, 0)
        XCTAssertEqual(shown.departed, 0, "names of runners already out on the course go first")
        XCTAssertEqual(shown.hiddenCurrent, 2, "and the crew is told how many are missing")
    }

    func testOneRowOfRoomStillShowsSomething() {
        let shown = StartSchedule.rowAllocation(fitting: 0, departed: 3, current: 5, next: 3)
        XCTAssertEqual(shown.current, 1)
        XCTAssertEqual(shown.hiddenCurrent, 4)
    }

    func testSpareRoomGoesToTheNextGroupBeforeTheDepartedOne() {
        let shown = StartSchedule.rowAllocation(fitting: 8, departed: 3, current: 6, next: 3)
        XCTAssertEqual(shown.current, 6)
        XCTAssertEqual(shown.next, 2)
        XCTAssertEqual(shown.departed, 0)
    }
}

/// Fitting a whole start group on screen. A mass start puts tens of runners in
/// one minute, and a crew calling names cannot work from "+27 more".
final class BannerFitTests: XCTestCase {

    /// Roughly an iPad in portrait: a wide banner with room for ten rows.
    private func fit(_ count: Int,
                     scale: Double = 1.0,
                     height: Double = 280,
                     width: Double = 1300) -> StartSchedule.BannerFit {
        StartSchedule.fit(
            currentCount: count,
            requestedScale: scale, availableHeight: height, availableWidth: width
        )
    }

    func testASmallGroupKeepsItsContextAndTextSize() {
        let result = fit(4)
        XCTAssertTrue(result.showsContext)
        XCTAssertEqual(result.columns, 1)
        XCTAssertEqual(result.scale, 1.0, accuracy: 0.001)
        XCTAssertEqual(result.hidden, 0)
    }

    /// A group that fills the banner on its own keeps the single-column layout;
    /// the groups around it are squeezed out one row at a time by the allocator.
    func testAGroupFillingTheBannerPushesTheContextOut() {
        let result = fit(10)
        XCTAssertEqual(result.columns, 1)
        XCTAssertEqual(result.hidden, 0)

        let shown = StartSchedule.rowAllocation(fitting: 10, departed: 3, current: 10, next: 3)
        XCTAssertEqual(shown.current, 10, "everyone starting is shown")
        XCTAssertEqual(shown.next, 0)
        XCTAssertEqual(shown.departed, 0, "the ones already running give way first")
        XCTAssertEqual(shown.hiddenCurrent, 0)
    }

    func testAMassStartWidensIntoColumnsBeforeShrinkingTheText() {
        let result = fit(33)
        XCTAssertGreaterThan(result.columns, 1, "columns come before smaller text")
        XCTAssertGreaterThan(result.scale, 0.8, "and the text barely moves")
        XCTAssertGreaterThanOrEqual(result.columns * result.rowsPerColumn, 33)
        XCTAssertEqual(result.hidden, 0, "everyone starting is on screen")
    }

    /// Thirty runners fit in three columns without shrinking at all.
    func testColumnsAloneCanBeEnough() {
        let result = fit(30)
        XCTAssertEqual(result.scale, 1.0, accuracy: 0.001)
        XCTAssertEqual(result.hidden, 0)
    }

    func testColumnsAreBalanced() {
        let result = fit(33)
        // No column may be taller than the banner allows.
        XCTAssertLessThanOrEqual(result.rowsPerColumn * result.columns - 33, result.columns)
    }

    func testANarrowScreenShrinksTheTextInstead() {
        let result = fit(20, width: 320)
        XCTAssertEqual(result.columns, 1, "no room for a second column")
        XCTAssertLessThan(result.scale, 1.0)
        XCTAssertEqual(result.hidden, 0)
    }

    func testTextNeverShrinksBelowTheReadableFloor() {
        let result = fit(400, height: 200, width: 400)
        XCTAssertEqual(result.scale, StartSchedule.minBannerScale, accuracy: 0.001)
        XCTAssertGreaterThan(result.hidden, 0, "only now does the banner admit to hiding anyone")
    }

    func testABiggerRequestedSizeIsHonouredWhenItFits() {
        let result = fit(3, scale: 2.0, height: 400)
        XCTAssertEqual(result.scale, 2.0, accuracy: 0.001)
    }

    func testNoRunnersNeedsNoColumns() {
        let result = fit(0)
        XCTAssertEqual(result.rowsPerColumn, 0)
        XCTAssertEqual(result.hidden, 0)
    }
}
