import XCTest
@testable import startclock

/// liveresultat serves JSON that is occasionally invalid. These cases come from
/// real responses — one bad competition name used to break the whole picker.
final class JSONRepairTests: XCTestCase {

    private func sanitized(_ raw: String) -> Data {
        JSONRepair.sanitize(Data(raw.utf8))
    }

    func testValidJSONIsUnchanged() throws {
        let raw = #"{"competitions":[{"id":1,"name":"Vårtävling","date":"2026-05-01","timediff":0}]}"#
        let decoded = try JSONDecoder().decode(CompetitionsResponse.self, from: sanitized(raw))
        XCTAssertEqual(decoded.competitions.first?.name, "Vårtävling")
    }

    func testUnescapedQuotesInsideValueAreRepaired() throws {
        // Verbatim from the live endpoint, which fails strict JSON parsing.
        let raw = #"{"competitions":[{"id":41082,"name":"1. Lauf "ORIUNITE" Nikolaus-OL","organizer":"SV IHW","date":"2026-12-06","timediff":0}]}"#
        let decoded = try JSONDecoder().decode(CompetitionsResponse.self, from: sanitized(raw))
        XCTAssertEqual(decoded.competitions.count, 1)
        XCTAssertEqual(decoded.competitions.first?.name, #"1. Lauf "ORIUNITE" Nikolaus-OL"#)
    }

    func testQuoteImmediatelyBeforeClosingIsRepaired() throws {
        let raw = #"{"competitions":[{"id":7,"name":"Kupa "Kracra"","organizer":"X","date":"2026-01-01","timediff":0}]}"#
        let decoded = try JSONDecoder().decode(CompetitionsResponse.self, from: sanitized(raw))
        XCTAssertEqual(decoded.competitions.first?.name, #"Kupa "Kracra""#)
    }

    func testAlreadyEscapedQuotesSurvive() throws {
        let raw = #"{"competitions":[{"id":9,"name":"OK \"Linné\"","organizer":"Y","date":"2026-01-01","timediff":0}]}"#
        let decoded = try JSONDecoder().decode(CompetitionsResponse.self, from: sanitized(raw))
        XCTAssertEqual(decoded.competitions.first?.name, #"OK "Linné""#)
    }

    func testControlCharactersAreStripped() throws {
        let raw = "{\"competitions\":[{\"id\":3,\"name\":\"Natt\u{0007}tävling\",\"date\":\"2026-02-02\",\"timediff\":0}]}"
        let decoded = try JSONDecoder().decode(CompetitionsResponse.self, from: sanitized(raw))
        XCTAssertEqual(decoded.competitions.first?.name, "Natttävling")
    }

    func testRunnerNamesWithStrayQuotesDecode() throws {
        let raw = #"{"status":"OK","results":[{"name":"Nils "Nisse" Svensson","club":"OK Linné","start":3768600}]}"#
        let decoded = try JSONDecoder().decode(ClassResultsResponse.self, from: sanitized(raw))
        XCTAssertEqual(decoded.results?.first?.name, #"Nils "Nisse" Svensson"#)
        XCTAssertEqual(decoded.results?.first?.start, 3_768_600)
    }

    /// A stray quote sitting right before a comma — the hard case, since a real
    /// closing quote looks the same until you read past the comma.
    func testStrayQuoteBeforeACommaIsRepaired() throws {
        let raw = #"{"competitions":[{"id":5,"name":"Nisse "Kalle", IF","organizer":"Z","date":"2026-03-03","timediff":0}]}"#
        let decoded = try JSONDecoder().decode(CompetitionsResponse.self, from: sanitized(raw))
        XCTAssertEqual(decoded.competitions.first?.name, #"Nisse "Kalle", IF"#)
        XCTAssertEqual(decoded.competitions.first?.organizer, "Z")
    }

    func testOrdinaryStringsBeforeCommasStillClose() throws {
        let raw = #"{"status":"OK","classes":[{"className":"H21"},{"className":"D21"}]}"#
        let decoded = try JSONDecoder().decode(ClassesResponse.self, from: sanitized(raw))
        XCTAssertEqual(decoded.classes.map(\.className), ["H21", "D21"])
    }
}
