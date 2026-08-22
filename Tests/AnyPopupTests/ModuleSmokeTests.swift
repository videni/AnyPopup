import XCTest
@testable import AnyPopup

final class ModuleSmokeTests: XCTestCase {
    func testModuleExportsVersion() {
        XCTAssertEqual(AnyPopupVersion.current, "0.1.0")
    }
}
