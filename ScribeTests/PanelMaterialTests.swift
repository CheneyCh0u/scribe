import SwiftUI
import XCTest
@testable import Scribe

@MainActor
final class PanelMaterialTests: XCTestCase {
    func testHostingViewDoesNotCoverNativeMaterial() {
        let hostingView = MaterialHostingView(rootView: Color.clear)

        XCTAssertFalse(hostingView.isOpaque)
    }
}
