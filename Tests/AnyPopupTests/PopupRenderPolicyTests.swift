import XCTest
@testable import AnyPopup

final class PopupRenderPolicyTests: XCTestCase {
    func testContainerAndAnchoredUseDifferentBodyOwnedSizing() {
        XCTAssertTrue(
            PopupRenderSizingPolicy.fillsResolvedFrame(
                for: .container(.center())
            )
        )
        XCTAssertFalse(
            PopupRenderSizingPolicy.fillsResolvedFrame(
                for: .anchored(AnchoredPopupConfig())
            )
        )
    }

}
