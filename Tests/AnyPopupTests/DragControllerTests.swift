import XCTest
@testable import AnyPopup

final class DragControllerTests: XCTestCase {
    func testBottomPositiveTranslationPastThresholdDismisses() {
        let result = DragController.resolve(
            translation: 301,
            velocity: 0,
            extent: 900,
            currentHeight: 400,
            contentHeight: 400,
            configuration: .bottom(dismissalThreshold: 1.0 / 3.0)
        )

        XCTAssertEqual(result, .dismiss)
    }

    func testTopNegativeTranslationPastThresholdDismisses() {
        let result = DragController.resolve(
            translation: -301,
            velocity: 0,
            extent: 900,
            currentHeight: 400,
            contentHeight: 400,
            configuration: .top(dismissalThreshold: 1.0 / 3.0)
        )

        XCTAssertEqual(result, .dismiss)
    }

    func testFastOutwardVelocityCanDismissBeforeDistanceThreshold() {
        let result = DragController.resolve(
            translation: 100,
            velocity: 1_500,
            extent: 900,
            currentHeight: 400,
            contentHeight: 400,
            configuration: .bottom(dismissalThreshold: 1.0 / 3.0)
        )

        XCTAssertEqual(result, .dismiss)
    }

    func testDismissalThresholdUsesPopupHeightInsteadOfScreenHeight() {
        let result = DragController.resolve(
            translation: 150,
            velocity: 0,
            extent: 1_000,
            currentHeight: 400,
            contentHeight: 400,
            configuration: .bottom(dismissalThreshold: 1.0 / 3.0)
        )

        XCTAssertEqual(result, .dismiss)
    }

    func testGlobalGestureStartConvertsToPopupLocalCoordinates() {
        let popupFrame = CGRect(x: 0, y: 300, width: 500, height: 400)

        XCTAssertEqual(
            DragController.localStartLocation(
                globalLocation: 340,
                popupFrame: popupFrame
            ),
            40
        )
    }

    func testDisabledDragAlwaysCancels() {
        let result = DragController.resolve(
            translation: 900,
            velocity: 2_000,
            extent: 900,
            currentHeight: 400,
            contentHeight: 400,
            configuration: .bottom(isEnabled: false)
        )

        XCTAssertEqual(result, .cancel)
    }

    func testReverseBottomDragSnapsToNextDetentAfterThreshold() {
        let result = DragController.resolve(
            translation: -100,
            velocity: 0,
            extent: 900,
            currentHeight: 400,
            contentHeight: 400,
            configuration: .bottom(
                dismissalThreshold: 1.0 / 3.0,
                detents: [.fixed(600), .large, .fullscreen]
            ),
            largeExtent: 800
        )

        XCTAssertEqual(result, .snap(height: 600))
    }

    func testReverseBottomDragBelowThresholdCancelsWithSpring() {
        let result = DragController.resolve(
            translation: -50,
            velocity: 0,
            extent: 900,
            currentHeight: 400,
            contentHeight: 400,
            configuration: .bottom(
                dismissalThreshold: 1.0 / 3.0,
                detents: [.fixed(600)]
            )
        )

        XCTAssertEqual(result, .cancel)
    }

    func testReverseTopDragSnapsToNextDetentSymmetrically() {
        let result = DragController.resolve(
            translation: 100,
            velocity: 0,
            extent: 900,
            currentHeight: 400,
            contentHeight: 400,
            configuration: .top(
                dismissalThreshold: 1.0 / 3.0,
                detents: [.fixed(600)]
            )
        )

        XCTAssertEqual(result, .snap(height: 600))
    }

    func testExpandedPopupCanCollapseToLowerDetentWithoutDismissal() {
        let result = DragController.resolve(
            translation: 100,
            velocity: 0,
            extent: 900,
            currentHeight: 600,
            contentHeight: 400,
            configuration: .bottom(
                dismissalThreshold: 1.0 / 3.0,
                detents: [.fixed(600), .large]
            ),
            largeExtent: 800
        )

        XCTAssertEqual(result, .snap(height: 400))
    }

    func testDetentHeightsCoverFixedFractionLargeAndFullscreen() {
        let heights = DragController.resolvedDetentHeights(
            [.fixed(300), .fraction(0.5), .large, .fullscreen],
            contentHeight: 200,
            extent: 1_000,
            largeExtent: 900
        )

        XCTAssertEqual(heights, [200, 300, 500, 900, 1_000])
    }

    func testTopAndBottomConfigsProduceSymmetricRuntimeConfigurations() {
        let top = TopPopupConfig()
        let bottom = BottomPopupConfig()

        XCTAssertEqual(top.dragConfiguration.edge, .top)
        XCTAssertEqual(bottom.dragConfiguration.edge, .bottom)
        XCTAssertEqual(top.dragConfiguration.detents, top.detents)
        XCTAssertEqual(bottom.dragConfiguration.detents, bottom.detents)
        XCTAssertEqual(top.dragConfiguration.activationArea, top.drag.activationArea)
        XCTAssertEqual(bottom.dragConfiguration.activationArea, bottom.drag.activationArea)
    }

    func testGestureMustStartInsideAttachedHandleArea() {
        let bottom = PopupDragConfiguration.bottom(activationArea: 30)
        let top = PopupDragConfiguration.top(activationArea: 30)

        XCTAssertTrue(DragController.isValidStart(location: 20, extent: 400, configuration: bottom))
        XCTAssertFalse(DragController.isValidStart(location: 40, extent: 400, configuration: bottom))
        XCTAssertTrue(DragController.isValidStart(location: 380, extent: 400, configuration: top))
        XCTAssertFalse(DragController.isValidStart(location: 360, extent: 400, configuration: top))
    }

    func testNonFiniteGestureCancels() {
        XCTAssertEqual(
            DragController.resolve(
                translation: .nan,
                velocity: 0,
                extent: 900,
                currentHeight: 400,
                contentHeight: 400,
                configuration: .bottom()
            ),
            .cancel
        )
    }
}
