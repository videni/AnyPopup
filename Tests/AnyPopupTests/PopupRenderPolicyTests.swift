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

    func testLivePopupOnlyOwnsInsertionTransition() {
        let plan = PopupRenderRole.live.transitionPlan(
            insertion: .scaleAndOpacity,
            removal: .move(to: .bottom)
        )

        XCTAssertEqual(plan.insertion, .scaleAndOpacity)
        XCTAssertEqual(plan.removal, .identity)
    }

    func testDismissalSnapshotDoesNotRunSecondSwiftUITransition() {
        let plan = PopupRenderRole.dismissalSnapshot.transitionPlan(
            insertion: .scaleAndOpacity,
            removal: .move(to: .bottom)
        )

        XCTAssertEqual(plan.insertion, .identity)
        XCTAssertEqual(plan.removal, .identity)
    }
}
