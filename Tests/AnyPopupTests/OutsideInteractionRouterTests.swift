import XCTest
@testable import AnyPopup

final class OutsideInteractionRouterTests: XCTestCase {
    private let regions = [
        PopupInteractionRegion(id: "A", frame: CGRect(x: 100, y: 100, width: 300, height: 300)),
        PopupInteractionRegion(id: "B", frame: CGRect(x: 400, y: 100, width: 200, height: 200))
    ]

    func testDismissToHitPopupRemovesOnlySuffix() {
        let action = OutsideInteractionRouter.action(
            at: CGPoint(x: 150, y: 150),
            regions: regions,
            topPolicy: .dismissToHitPopup,
            gesture: .idle
        )

        XCTAssertEqual(action, .dismissSuffix(above: "A"))
    }

    func testDismissToHitPopupDismissesAllWhenNothingIsHit() {
        let action = OutsideInteractionRouter.action(
            at: CGPoint(x: 20, y: 20),
            regions: regions,
            topPolicy: .dismissToHitPopup,
            gesture: .idle
        )

        XCTAssertEqual(action, .dismissAll)
    }

    func testTopPopupHitRoutesToTopWithoutOutsideAction() {
        let action = OutsideInteractionRouter.action(
            at: CGPoint(x: 450, y: 150),
            regions: regions,
            topPolicy: .dismissTop,
            gesture: .idle
        )

        XCTAssertEqual(action, .routeToPopup("B"))
    }

    func testDismissTopAndConsumeNeverPassSameEventThrough() {
        XCTAssertEqual(
            OutsideInteractionRouter.action(
                at: CGPoint(x: 150, y: 150),
                regions: regions,
                topPolicy: .dismissTop,
                gesture: .idle
            ),
            .dismissTop
        )
        XCTAssertEqual(
            OutsideInteractionRouter.action(
                at: CGPoint(x: 20, y: 20),
                regions: regions,
                topPolicy: .consume,
                gesture: .idle
            ),
            .consume
        )
    }

    func testPassThroughTargetsLowerPopupOrUnderlyingApp() {
        XCTAssertEqual(
            OutsideInteractionRouter.action(
                at: CGPoint(x: 150, y: 150),
                regions: regions,
                topPolicy: .passThrough,
                gesture: .idle
            ),
            .passThrough(to: "A")
        )
        XCTAssertEqual(
            OutsideInteractionRouter.action(
                at: CGPoint(x: 20, y: 20),
                regions: regions,
                topPolicy: .passThrough,
                gesture: .idle
            ),
            .passThrough(to: nil)
        )
    }

    func testDraggingConsumesOutsideInteraction() {
        let action = OutsideInteractionRouter.action(
            at: CGPoint(x: 20, y: 20),
            regions: regions,
            topPolicy: .passThrough,
            gesture: .dragging
        )

        XCTAssertEqual(action, .consume)
    }

    func testNoPopupRoutesToUnderlyingApp() {
        let action = OutsideInteractionRouter.action(
            at: .zero,
            regions: [PopupInteractionRegion<String>](),
            topPolicy: .consume,
            gesture: .idle
        )

        XCTAssertEqual(action, .passThrough(to: nil))
    }
}
