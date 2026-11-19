import XCTest
@testable import startclock

/// How start times are shown, and how an Eventor page is read.
final class StartListTests: XCTestCase {

    private func entry(centiseconds: Int?) -> StartEntry {
        StartEntry(name: "Runner", club: nil, start: centiseconds, startnumber: nil)
    }

    // MARK: - Time format, decided per list

    func testWholeMinuteListShowsNoSeconds() {
        let entries = [entry(centiseconds: 10 * 3600 * 100), entry(centiseconds: 10 * 3600 * 100 + 6000)]
        XCTAssertFalse(entries.usesSecondStarts)
        XCTAssertEqual(entries[0].startTimeString(showSeconds: false), "10:00")
    }

    func testOneSecondStartSwitchesTheWholeList() {
        let entries = [entry(centiseconds: 10 * 3600 * 100), entry(centiseconds: 10 * 3600 * 100 + 3000)]
        XCTAssertTrue(entries.usesSecondStarts, "a start at 10:00:30 must switch the list to seconds")
        XCTAssertEqual(entries[1].startTimeString(showSeconds: true), "10:00:30")
    }

    func testMissingStartTimeIsShownAsPlaceholder() {
        XCTAssertEqual(entry(centiseconds: nil).startTimeString(showSeconds: false), "--:--")
        XCTAssertEqual(entry(centiseconds: nil).startTimeString(showSeconds: true), "--:--:--")
    }

    func testEntriesWithoutStartTimeDoNotForceSeconds() {
        XCTAssertFalse([entry(centiseconds: nil), entry(centiseconds: 0)].usesSecondStarts)
    }

    // MARK: - Eventor HTML

    func testParsesClassHeadingsAndRows() {
        let html = """
        <html><head><title>Startlista - Vårtävlingen</title></head><body>
        <h2>H21</h2>
        <table><tr><th>Tid</th><th>Namn</th></tr>
        <tr><td>18:06:00</td><td>Anna Andersson</td><td>OK Linné</td></tr>
        <tr><td>18:08:00</td><td>Bertil Bok</td><td>IFK Mora</td></tr>
        </table>
        <h2>D21</h2>
        <table><tr><td>18:10:30</td><td>Cecilia Carlsson</td><td>Järfälla OK</td></tr></table>
        </body></html>
        """
        var name = "Eventor"
        let entries = EventorManager.parseStartList(html: html, name: &name)

        XCTAssertEqual(name, "Startlista - Vårtävlingen")
        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries[0].name, "Anna Andersson")
        XCTAssertEqual(entries[0].club, "OK Linné")
        XCTAssertEqual(entries[0].className, "H21")
        XCTAssertEqual(entries[0].startSeconds, 18 * 3600 + 6 * 60)
        XCTAssertEqual(entries[2].className, "D21", "rows must take the heading above them")
        XCTAssertEqual(entries[2].startSeconds, 18 * 3600 + 10 * 60 + 30)
    }

    func testHeaderRowsAndRowsWithoutATimeAreSkipped() {
        let html = """
        <h2>H21</h2><table>
        <tr><th>18:06:00</th><th>Header</th></tr>
        <tr><td>Vakant</td><td></td></tr>
        <tr><td>18:06:00</td><td>Anna Andersson</td></tr>
        </table>
        """
        var name = "Eventor"
        XCTAssertEqual(EventorManager.parseStartList(html: html, name: &name).count, 1)
    }

    func testRejectsImpossibleClockTimes() {
        XCTAssertNil(EventorManager.timeToCentisecs("25:00"))
        XCTAssertNil(EventorManager.timeToCentisecs("10:61"))
        XCTAssertEqual(EventorManager.timeToCentisecs("09:05:07"), (9 * 3600 + 5 * 60 + 7) * 100)
    }
}

/// A background refresh must never downgrade a loaded start list.
/// Seen at a start: the class column disappeared part-way through, because the
/// five-minute HTML poll replaced a browser import that had the classes.
final class EventorRefreshTests: XCTestCase {

    private func entry(_ name: String, className: String, start: Int = 10 * 3600 * 100) -> StartEntry {
        var e = StartEntry(name: name, club: nil, start: start, startnumber: nil)
        e.className = className
        return e
    }

    private var loaded: [StartEntry] {
        [entry("Anna", className: "D21"), entry("Bertil", className: "H21")]
    }

    func testRefreshLosingClassNamesIsRejected() {
        let worse = [entry("Anna", className: ""), entry("Bertil", className: "")]
        XCTAssertFalse(EventorManager.acceptsRefresh(worse, replacing: loaded))
    }

    func testRefreshLosingRunnersIsRejected() {
        XCTAssertFalse(EventorManager.acceptsRefresh([entry("Anna", className: "D21")], replacing: loaded))
    }

    func testEmptyRefreshIsRejected() {
        XCTAssertFalse(EventorManager.acceptsRefresh([], replacing: loaded))
    }

    func testRefreshAddingRunnersIsAccepted() {
        let better = loaded + [entry("Cecilia", className: "D16")]
        XCTAssertTrue(EventorManager.acceptsRefresh(better, replacing: loaded))
    }

    func testFirstImportIsAlwaysAccepted() {
        XCTAssertTrue(EventorManager.acceptsRefresh(loaded, replacing: []))
    }

    /// A list that never had classes is not held back by this rule.
    func testRefreshWithoutClassesIsFineWhenThereWereNone() {
        let classless = [entry("Anna", className: ""), entry("Bertil", className: "")]
        XCTAssertTrue(EventorManager.acceptsRefresh(classless, replacing: classless))
    }
}

/// An imported start list is kept in UserDefaults as JSON and read back on
/// launch. The class names used to be dropped on the way through, so an Eventor
/// list lost its class column as soon as the app was restarted.
final class StartEntryCodingTests: XCTestCase {

    func testClassNameSurvivesARoundTrip() throws {
        let list = OfflineStartList(
            name: "Höstrusket",
            importedAt: Date(timeIntervalSince1970: 1_763_000_000),
            entries: [StartEntry(name: "Anna", club: "OK Linné", start: 3_768_600,
                                 startnumber: nil, className: "D21")]
        )
        let data    = try JSONEncoder().encode(list)
        let decoded = try JSONDecoder().decode(OfflineStartList.self, from: data)

        XCTAssertEqual(decoded.entries.first?.className, "D21")
        XCTAssertEqual(decoded.entries.first?.club, "OK Linné")
        XCTAssertEqual(decoded, list)
    }

    /// The liveresultat API never sends a class name — it comes from the class
    /// that was fetched — so its absence must decode, not throw.
    func testApiResponseWithoutAClassNameDecodes() throws {
        let raw = #"{"status":"OK","results":[{"name":"Bertil","club":"IFK Mora","start":3600000}]}"#
        let decoded = try JSONDecoder().decode(ClassResultsResponse.self, from: Data(raw.utf8))
        XCTAssertEqual(decoded.results?.first?.className, "")
        XCTAssertEqual(decoded.results?.first?.startSeconds, 36000)
    }

    func testListsSavedBeforeClassNamesWereKeptStillLoad() throws {
        let legacy = #"{"name":"Old","importedAt":0,"entries":[{"name":"Cecilia","start":3600000}]}"#
        let decoded = try JSONDecoder().decode(OfflineStartList.self, from: Data(legacy.utf8))
        XCTAssertEqual(decoded.entries.first?.className, "")
    }
}
