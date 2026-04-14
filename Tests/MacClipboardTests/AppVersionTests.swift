@testable import MacClipboard
import XCTest

final class AppVersionTests: XCTestCase {
    func testIgnoresLeadingVPrefix() {
        XCTAssertEqual(AppVersion("v1.2.3")?.description, "1.2.3")
    }

    func testComparesVersionComponentsLexicographically() throws {
        XCTAssertLessThan(try XCTUnwrap(AppVersion("1.2.9")), try XCTUnwrap(AppVersion("1.10.0")))
        XCTAssertGreaterThan(try XCTUnwrap(AppVersion("2.0")), try XCTUnwrap(AppVersion("1.9.9")))
    }

    func testTreatsMissingPatchAsZero() {
        XCTAssertEqual(AppVersion("1.2"), AppVersion("1.2.0"))
    }

    func testRejectsNonNumericComponents() {
        XCTAssertNil(AppVersion("1.2.beta"))
    }
}
