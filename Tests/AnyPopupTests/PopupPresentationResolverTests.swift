import SwiftUI
import XCTest
@testable import AnyPopup

final class PopupPresentationResolverTests: XCTestCase {
    func testResponsiveBottomBranchUsesSafeAreaAndKeyboardVisibleFrame() {
        let config = ContainerPopupConfig.center()
            .when(.containerWidthLessThan(600), use: .bottom(BottomPopupConfig()))
        let environment = PopupEnvironment(
            containerSize: CGSize(width: 500, height: 800),
            safeArea: EdgeInsets(top: 20, leading: 0, bottom: 20, trailing: 0),
            keyboardOcclusionHeight: 100,
            accessibilityReduceMotion: false
        )

        let presentation = PopupPresentationResolver.resolve(
            config: config,
            environment: environment,
            contentSize: CGSize(width: 400, height: 300)
        )

        XCTAssertEqual(presentation.frame, CGRect(x: 50, y: 380, width: 400, height: 300))
        XCTAssertEqual(presentation.drag, DragPolicy(direction: .down))
        XCTAssertEqual(presentation.stackAppearance, .stacked)
        XCTAssertNil(presentation.anchoredGeometry)
    }

    func testBottomIgnoringBottomSafeAreaTouchesContainerBottom() {
        let environment = PopupEnvironment(
            containerSize: CGSize(width: 500, height: 800),
            safeArea: EdgeInsets(top: 24, leading: 0, bottom: 20, trailing: 0),
            keyboardOcclusionHeight: 0,
            accessibilityReduceMotion: false
        )
        let config = ContainerPopupConfig.bottom(
            BottomPopupConfig()
                .size(width: .fill, height: .fraction(0.85))
                .ignoreSafeArea(edges: .bottom)
        )

        let presentation = PopupPresentationResolver.resolve(
            config: config,
            environment: environment,
            contentSize: CGSize(width: 500, height: 300)
        )

        XCTAssertEqual(presentation.frame.maxY, environment.containerSize.height)
    }

    func testCenterMovesIntoKeyboardVisibleRegion() {
        let environment = PopupEnvironment(
            containerSize: CGSize(width: 1_000, height: 800),
            safeArea: EdgeInsets(top: 20, leading: 10, bottom: 20, trailing: 10),
            keyboardOcclusionHeight: 300,
            accessibilityReduceMotion: false
        )

        let presentation = PopupPresentationResolver.resolve(
            config: .center(),
            environment: environment,
            contentSize: CGSize(width: 400, height: 300)
        )

        XCTAssertEqual(presentation.frame, CGRect(x: 300, y: 100, width: 400, height: 300))
        XCTAssertFalse(presentation.drag.isEnabled)
    }

    func testAnchoredPresentationContainsArrowGeometry() throws {
        let presentation = try PopupPresentationResolver.resolve(
            config: AnchoredPopupConfig().anchor(source: .bottom, popup: .top),
            environment: environment(width: 500, height: 800),
            contentSize: CGSize(width: 100, height: 80),
            anchorFrame: CGRect(x: 200, y: 100, width: 40, height: 20)
        )

        XCTAssertEqual(presentation.frame, CGRect(x: 170, y: 120, width: 100, height: 80))
        XCTAssertEqual(presentation.outsideInteraction, .dismissTop)
        XCTAssertNotNil(presentation.anchoredGeometry)
    }

    func testAnchoredPopupStaysAboveKeyboardWhenEnabled() throws {
        let environment = PopupEnvironment(
            containerSize: CGSize(width: 1_000, height: 800),
            safeArea: EdgeInsets(top: 20, leading: 0, bottom: 20, trailing: 0),
            keyboardOcclusionHeight: 400,
            accessibilityReduceMotion: false
        )
        let config = AnchoredPopupConfig()
            .size(width: .fixed(400), height: .fixed(240))
            .anchor(source: .right, popup: .left)
            .screenAvoidance(edges: .all, padding: 8)
            .keyboardAvoidance(.moveIntoVisibleRegion)

        let presentation = try PopupPresentationResolver.resolve(
            config: config,
            environment: environment,
            contentSize: CGSize(width: 400, height: 240),
            anchorFrame: CGRect(x: 100, y: 350, width: 40, height: 20)
        )

        XCTAssertEqual(presentation.frame.maxY, 372)
    }

    func testAdaptiveAnchorPrefersRightEvenInPortrait() throws {
        let presentation = try PopupPresentationResolver.resolve(
            config: AnchoredPopupConfig()
                .size(width: .fixed(400), height: .fixed(430))
                .screenAvoidance(edges: .all, padding: 8)
                .adaptivePlacement(),
            environment: environment(width: 834, height: 1_194),
            contentSize: CGSize(width: 400, height: 430),
            anchorFrame: CGRect(x: 100, y: 500, width: 100, height: 30)
        )

        XCTAssertEqual(presentation.frame.minX, 208)
        XCTAssertEqual(presentation.anchoredGeometry?.sourcePointInPopup.x, -8)
    }

    func testAdaptiveAnchorMovesBelowWhenRightSpaceRunsOut() throws {
        let presentation = try PopupPresentationResolver.resolve(
            config: AnchoredPopupConfig()
                .size(width: .fixed(400), height: .fixed(430))
                .screenAvoidance(edges: .all, padding: 8)
                .adaptivePlacement(),
            environment: environment(width: 834, height: 1_194),
            contentSize: CGSize(width: 400, height: 430),
            anchorFrame: CGRect(x: 500, y: 300, width: 100, height: 30)
        )

        XCTAssertEqual(presentation.frame.minY, 338)
        XCTAssertEqual(presentation.anchoredGeometry?.sourcePointInPopup.y, -8)
    }

    func testVerticalAdaptiveAnchorPrefersBelowEvenWithRightSpace() throws {
        let presentation = try PopupPresentationResolver.resolve(
            config: AnchoredPopupConfig()
                .size(width: .fixed(300), height: .fixed(160))
                .screenAvoidance(edges: .all, padding: 8)
                .adaptivePlacement(prefer: .vertical),
            environment: environment(width: 834, height: 800),
            contentSize: CGSize(width: 300, height: 160),
            anchorFrame: CGRect(x: 100, y: 100, width: 40, height: 30)
        )

        XCTAssertEqual(presentation.frame.minY, 138)
        XCTAssertEqual(presentation.anchoredGeometry?.sourcePointInPopup.y, -8)
    }

    func testVerticalAdaptiveAnchorMovesAboveNearBottom() throws {
        let presentation = try PopupPresentationResolver.resolve(
            config: AnchoredPopupConfig()
                .size(width: .fixed(300), height: .fixed(160))
                .screenAvoidance(edges: .all, padding: 8)
                .adaptivePlacement(prefer: .vertical),
            environment: environment(width: 834, height: 800),
            contentSize: CGSize(width: 300, height: 160),
            anchorFrame: CGRect(x: 100, y: 700, width: 40, height: 30)
        )

        XCTAssertEqual(presentation.frame.maxY, 692)
        XCTAssertEqual(presentation.anchoredGeometry?.sourcePointInPopup.y, 168)
    }

    func testMissingAndInvalidAnchorFailExplicitly() {
        XCTAssertThrowsError(
            try PopupPresentationResolver.resolve(
                config: AnchoredPopupConfig(),
                environment: environment(width: 500, height: 800),
                contentSize: CGSize(width: 100, height: 80),
                anchorFrame: nil
            )
        ) { error in
            XCTAssertEqual(error as? PopupPresentationError, .missingAnchorFrame)
        }

        XCTAssertThrowsError(
            try PopupPresentationResolver.resolve(
                config: AnchoredPopupConfig(),
                environment: environment(width: 500, height: 800),
                contentSize: CGSize(width: 100, height: 80),
                anchorFrame: .zero
            )
        ) { error in
            XCTAssertEqual(error as? PopupPresentationError, .invalidAnchorFrame)
        }
    }
}

private extension PopupPresentationResolverTests {
    func environment(width: CGFloat, height: CGFloat) -> PopupEnvironment {
        PopupEnvironment(
            containerSize: CGSize(width: width, height: height),
            safeArea: EdgeInsets(),
            keyboardOcclusionHeight: 0,
            accessibilityReduceMotion: false
        )
    }
}
