import XCTest
@testable import startclock

final class ClockStyleTests: XCTestCase {

    /// The raw values are what sits in AppStorage on every installed device.
    /// Renaming one would silently reset that user's clock to SF Pro.
    func testRawValuesMatchWhatIsAlreadyStored() {
        XCTAssertEqual(
            ClockStyle.allCases.map(\.rawValue),
            ["sfpro", "sfCondensed", "sfCompressed", "newYork", "courierNew",
             "digital", "flapBoard", "analog", "analogSeconds",
             "hourOnly", "minuteOnly", "secondOnly"]
        )
    }

    func testUnknownStoredValueFallsBackToSFPro() {
        XCTAssertNil(ClockStyle(rawValue: "system"))   // removed in an earlier version
    }

    func testEveryStyleIsNamed() {
        for style in ClockStyle.allCases {
            XCTAssertFalse(style.displayName.isEmpty, "\(style.rawValue) has no name")
        }
    }

    func testArtworkFacesIgnoreBold() {
        XCTAssertFalse(ClockStyle.digital.usesBold)
        XCTAssertFalse(ClockStyle.flapBoard.usesBold)
        XCTAssertFalse(ClockStyle.analog.usesBold)
        XCTAssertTrue(ClockStyle.sfpro.usesBold)
        XCTAssertTrue(ClockStyle.secondOnly.usesBold)
    }
}
