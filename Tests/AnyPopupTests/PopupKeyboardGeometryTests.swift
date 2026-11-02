import CoreGraphics
import XCTest
@testable import AnyPopup

final class PopupKeyboardGeometryTests: XCTestCase {
    func testKeyboardBelowOffsetContainerDoesNotReduceItsHeight() {
        XCTAssertEqual(PopupKeyboardGeometry.occlusionHeight(container: CGRect(x: 70, y: 100, width: 500, height: 500),
            safeAreaBottom: 0, keyboard: CGRect(x: 0, y: 700, width: 800, height: 200)), 0)
    }
    func testOnlyOverlapAtContainerBottomIsExcluded() {
        XCTAssertEqual(PopupKeyboardGeometry.occlusionHeight(container: CGRect(x: 70, y: 450, width: 500, height: 350),
            safeAreaBottom: 20, keyboard: CGRect(x: 0, y: 700, width: 800, height: 200)), 80)
    }
    func testFloatingOrHorizontallySeparateKeyboardDoesNotMoveContainer() {
        let container = CGRect(x: 70, y: 450, width: 500, height: 350)
        XCTAssertEqual(PopupKeyboardGeometry.occlusionHeight(container: container, safeAreaBottom: 0,
            keyboard: CGRect(x: 0, y: 600, width: 800, height: 100)), 0)
        XCTAssertEqual(PopupKeyboardGeometry.occlusionHeight(container: container, safeAreaBottom: 0,
            keyboard: CGRect(x: 600, y: 700, width: 200, height: 200)), 0)
    }
}
