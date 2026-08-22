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
