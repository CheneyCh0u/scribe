import SwiftUI
import XCTest
@testable import Scribe

final class PanelSelectionTests: XCTestCase {
    func testOnlyRowMatchingSelectionIsSelected() {
        let first = makeItem(id: 1)
        let second = makeItem(id: 2)

        XCTAssertTrue(RowView(item: first, selectedID: .constant(1)).isSelected)
        XCTAssertFalse(RowView(item: second, selectedID: .constant(1)).isSelected)
    }

    func testRowWithoutPersistedIDIsNeverSelected() {
        XCTAssertFalse(RowView(item: makeItem(id: nil), selectedID: .constant(nil)).isSelected)
    }

    private func makeItem(id: Int64?) -> ClipItem {
        ClipItem(
            id: id,
            type: "text",
            content: "test",
            rtfData: nil,
            preview: "test",
            contentHash: "hash-\(id.map { String($0) } ?? "nil")",
            appBundleID: nil,
            appName: nil,
            isConcealed: false,
            pinned: false,
            createdAt: Date(),
            lastUsedAt: Date(),
            imagePath: nil,
            imageWidth: nil,
            imageHeight: nil,
            byteSize: nil
        )
    }
}
