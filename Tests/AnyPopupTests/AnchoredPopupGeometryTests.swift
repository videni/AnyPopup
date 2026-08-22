import SwiftUI
import XCTest
@testable import AnyPopup

final class AnchoredPopupGeometryTests: XCTestCase {
    func testNineAnchorPointsAlignExactly() {
        let anchorFrame = CGRect(x: 100, y: 200, width: 40, height: 60)
        let contentSize = CGSize(width: 20, height: 10)
        let expectedOrigins: [(PopupAnchorPoint, CGPoint)] = [
            (.topLeft, CGPoint(x: 100, y: 200)),
            (.top, CGPoint(x: 110, y: 200)),
            (.topRight, CGPoint(x: 120, y: 200)),
            (.left, CGPoint(x: 100, y: 225)),
            (.center, CGPoint(x: 110, y: 225)),
            (.right, CGPoint(x: 120, y: 225)),
            (.bottomLeft, CGPoint(x: 100, y: 250)),
            (.bottom, CGPoint(x: 110, y: 250)),
            (.bottomRight, CGPoint(x: 120, y: 250))
        ]

        for (anchor, expectedOrigin) in expectedOrigins {
            let geometry = AnchoredPopupGeometry.resolve(
                contentSize: contentSize,
                anchorFrame: anchorFrame,
                containerFrame: CGRect(x: 0, y: 0, width: 500, height: 800),
                config: AnchoredPopupConfig()
                    .anchor(source: anchor, popup: anchor)
                    .screenAvoidance(edges: [], padding: 0)
            )

            XCTAssertEqual(geometry.frame.origin, expectedOrigin, "Failed for \(anchor)")
        }
    }

    func testAnchorShiftKeepsPopupInsideHorizontalEdges() {
        let result = AnchoredPopupGeometry.resolve(
            contentSize: CGSize(width: 280, height: 200),
            anchorFrame: CGRect(x: 490, y: 100, width: 20, height: 20),
            containerFrame: CGRect(x: 0, y: 0, width: 500, height: 800),
            config: AnchoredPopupConfig().anchor(source: .bottom, popup: .top)
        )

        XCTAssertEqual(result.frame.maxX, 484)
        XCTAssertEqual(result.avoidanceShift, CGSize(width: -156, height: 0))
        XCTAssertEqual(result.sourcePoint, CGPoint(x: 500, y: 120))
        XCTAssertEqual(result.popupAnchorPoint, CGPoint(x: 344, y: 120))
        XCTAssertEqual(result.sourcePointInPopup, CGPoint(x: 296, y: 0))
    }

    func testVerticalAvoidanceUsesSafeAreaContainerFrame() {
        let result = AnchoredPopupGeometry.resolve(
            contentSize: CGSize(width: 100, height: 200),
            anchorFrame: CGRect(x: 200, y: 740, width: 20, height: 20),
            containerFrame: CGRect(x: 10, y: 30, width: 480, height: 720),
            config: AnchoredPopupConfig()
                .anchor(source: .bottom, popup: .top)
                .screenAvoidance(edges: .vertical, padding: 16)
        )

        XCTAssertEqual(result.frame.maxY, 734)
    }

    func testEmptyAvoidanceEdgesPreserveOverflow() {
        let result = AnchoredPopupGeometry.resolve(
            contentSize: CGSize(width: 280, height: 200),
            anchorFrame: CGRect(x: 490, y: 100, width: 20, height: 20),
            containerFrame: CGRect(x: 0, y: 0, width: 500, height: 800),
            config: AnchoredPopupConfig()
                .anchor(source: .bottom, popup: .top)
                .screenAvoidance(edges: [], padding: 0)
        )

        XCTAssertEqual(result.frame.maxX, 640)
        XCTAssertEqual(result.avoidanceShift, .zero)
    }
}
