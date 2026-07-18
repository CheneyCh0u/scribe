import XCTest
@testable import Scribe

final class PanelMaskTests: XCTestCase {
    func testRoundedMaskExcludesWindowCorners() {
        let rect = CGRect(origin: .zero, size: Tokens.Layout.panelSize)
        let path = PanelMask.path(in: rect, cornerRadius: Tokens.Radius.panel).cgPath

        XCTAssertFalse(path.contains(rect.origin))
        XCTAssertFalse(path.contains(CGPoint(x: rect.maxX, y: rect.maxY)))
        XCTAssertTrue(path.contains(CGPoint(x: rect.midX, y: rect.midY)))
    }

    func testRoundedMaskMatchesPanelSize() {
        let image = PanelMask.image(
            size: Tokens.Layout.panelSize,
            cornerRadius: Tokens.Radius.panel
        )

        XCTAssertEqual(image.size, Tokens.Layout.panelSize)
    }
}
