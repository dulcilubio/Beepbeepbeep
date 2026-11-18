import XCTest
@testable import startclock

/// The guard that keeps a stale cached GPS fix from moving the clock.
/// A competition was run on a clock about a minute slow because the first fix
/// delivered by Core Location was a cached one.
final class TimeSyncTests: XCTestCase {

    /// Feeds offsets one at a time, as fixes arrive, and reports the first one accepted.
    private func firstAcceptedOffset(_ stream: [TimeInterval]) -> TimeInterval? {
        var seen: [TimeInterval] = []
        for sample in stream {
            seen.append(sample)
            if let agreed = GNSSTimeManager.agreedOffset(from: seen) { return agreed }
        }
        return nil
    }

    func testStaleCachedFixIsRejectedInFavourOfTheFreshOnesBehindIt() throws {
        // A 60 s old cached fix arrives first, then normal 1 Hz fixes.
        let accepted = try XCTUnwrap(firstAcceptedOffset([-60.0, -0.02, -0.04, -0.01, -0.03]))
        XCTAssertEqual(accepted, -0.02, accuracy: 0.05,
                       "the cached fix must not reach the clock")
    }

    func testGenuineClockErrorIsStillCorrected() throws {
        // Every fresh fix agrees that the device clock is a minute behind.
        let accepted = try XCTUnwrap(firstAcceptedOffset([-61.20, -61.18, -61.22]))
        XCTAssertEqual(accepted, -61.20, accuracy: 0.05)
    }

    func testHealthyClockSyncsOnTheThirdFix() throws {
        let accepted = try XCTUnwrap(firstAcceptedOffset([-0.03, -0.02, -0.04]))
        XCTAssertEqual(accepted, -0.03, accuracy: 0.01)
    }

    func testDisagreeingFixesAreNeverApplied() {
        XCTAssertNil(firstAcceptedOffset([-12.0, -4.0, -30.0, -0.5]))
    }

    func testTwoFixesAreNotEnough() {
        XCTAssertNil(GNSSTimeManager.agreedOffset(from: [-0.02, -0.02]))
    }
}
