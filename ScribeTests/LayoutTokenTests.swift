import XCTest
@testable import Scribe

final class LayoutTokenTests: XCTestCase {
    func testSettingsWindowHasUsableExplicitSize() {
        XCTAssertEqual(Tokens.Layout.settingsSize.width, 460)
        XCTAssertGreaterThanOrEqual(Tokens.Layout.settingsSize.height, 320)
    }
}
