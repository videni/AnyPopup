import SwiftUI
import XCTest
@testable import AnyPopup

final class ContainerPopupGeometryTests: XCTestCase {
    func testTopCanAlignLeadingAndApplyConfiguredOffset() {
        let frame = ContainerPopupGeometry.top(
            contentSize: CGSize(width: 380, height: 500),
            availableFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800),
            config: TopPopupConfig()
                .size(width: .fixed(380), height: .fixed(500))
                .position(horizontal: .leading, offset: CGSize(width: 16, height: 72))
        )

        XCTAssertEqual(frame, CGRect(x: 16, y: 72, width: 380, height: 500))
    }

    func testBottomCanAlignTrailingAndApplyConfiguredOffset() {
        let frame = ContainerPopupGeometry.bottom(
            contentSize: CGSize(width: 300, height: 200),
            availableFrame: CGRect(x: 10, y: 20, width: 800, height: 600),
            config: BottomPopupConfig()
                .size(width: .fixed(300), height: .fixed(200))
                .position(horizontal: .trailing, offset: CGSize(width: -12, height: -8))
        )

        XCTAssertEqual(frame, CGRect(x: 498, y: 412, width: 300, height: 200))
    }

    func testCenterFrameUsesVisibleContainer() {
        let frame = ContainerPopupGeometry.center(
            contentSize: CGSize(width: 400, height: 300),
            availableFrame: CGRect(x: 0, y: 20, width: 1_000, height: 780),
            config: CenterPopupConfig()
        )

        XCTAssertEqual(frame, CGRect(x: 300, y: 260, width: 400, height: 300))
    }

    func testTopAndBottomUseAvailableFrameEdges() {
        let availableFrame = CGRect(x: 20, y: 50, width: 460, height: 700)
        let contentSize = CGSize(width: 200, height: 100)

        XCTAssertEqual(
            ContainerPopupGeometry.top(
                contentSize: contentSize,
                availableFrame: availableFrame,
                config: TopPopupConfig()
            ),
            CGRect(x: 150, y: 50, width: 200, height: 100)
        )
        XCTAssertEqual(
            ContainerPopupGeometry.bottom(
                contentSize: contentSize,
                availableFrame: availableFrame,
                config: BottomPopupConfig()
            ),
            CGRect(x: 150, y: 650, width: 200, height: 100)
        )
    }

    func testContainerSizePoliciesResolveAgainstAvailableFrame() {
        let availableFrame = CGRect(x: 20, y: 50, width: 460, height: 700)
        let config = BottomPopupConfig().size(
            width: .fraction(0.5),
            height: .fixed(200)
        )

        let frame = ContainerPopupGeometry.bottom(
            contentSize: CGSize(width: 900, height: 900),
            availableFrame: availableFrame,
            config: config
        )

        XCTAssertEqual(frame, CGRect(x: 135, y: 550, width: 230, height: 200))
    }

    func testContentSizeIsClampedToVisibleContainer() {
        let frame = ContainerPopupGeometry.center(
            contentSize: CGSize(width: 600, height: 900),
            availableFrame: CGRect(x: 20, y: 50, width: 460, height: 700),
            config: CenterPopupConfig()
        )

        XCTAssertEqual(frame, CGRect(x: 20, y: 50, width: 460, height: 700))
    }
}
