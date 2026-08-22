import XCTest
@testable import AnyPopup

final class PopupWindowRoutingTests: XCTestCase {
    func testWindowPassesThroughOutsideAllRegions() {
        let map = PopupInteractionMap()

        XCTAssertEqual(PopupWindowRouting.hitTarget(at: .zero, interactionMap: map), .passThrough)
    }

    func testWindowCapturesTopPopupAndItsShield() {
        let bottom = PopupID()
        let top = PopupID()
        let map = interactionMap(
            regions: [
                PopupInteractionRegion(id: bottom, frame: CGRect(x: 10, y: 10, width: 100, height: 100)),
                PopupInteractionRegion(id: top, frame: CGRect(x: 200, y: 200, width: 100, height: 100))
            ],
            topPolicy: .dismissTop
        )

        XCTAssertEqual(
            PopupWindowRouting.hitTarget(at: CGPoint(x: 220, y: 220), interactionMap: map),
            .popup(top)
        )
        XCTAssertEqual(
            PopupWindowRouting.hitTarget(at: CGPoint(x: 20, y: 20), interactionMap: map),
            .shield
        )
        XCTAssertEqual(
            PopupWindowRouting.hitTarget(at: CGPoint(x: 500, y: 500), interactionMap: map),
            .shield
        )
    }

    func testPassThroughPolicyCapturesPopupRegionsOnly() {
        let bottom = PopupID()
        let top = PopupID()
        let map = interactionMap(
            regions: [
                PopupInteractionRegion(id: bottom, frame: CGRect(x: 10, y: 10, width: 100, height: 100)),
                PopupInteractionRegion(id: top, frame: CGRect(x: 200, y: 200, width: 100, height: 100))
            ],
            topPolicy: .passThrough
        )

        XCTAssertEqual(
            PopupWindowRouting.hitTarget(at: CGPoint(x: 20, y: 20), interactionMap: map),
            .popup(bottom)
        )
        XCTAssertEqual(
            PopupWindowRouting.hitTarget(at: CGPoint(x: 500, y: 500), interactionMap: map),
            .passThrough
        )
    }

    func testDismissalAlwaysCapturesShield() {
        let map = PopupInteractionMap()
        map.beginDismissal(count: 1)

        XCTAssertEqual(
            PopupWindowRouting.hitTarget(at: CGPoint(x: 500, y: 500), interactionMap: map),
            .shield
        )
    }
}

private func interactionMap(
    regions: [PopupInteractionRegion<PopupID>],
    topPolicy: OutsideInteractionPolicy
) -> PopupInteractionMap {
    let map = PopupInteractionMap()
    map.replace(
        with: PopupInteractionMap.Snapshot(
            regions: regions,
            topPolicy: topPolicy
        )
    )
    return map
}
