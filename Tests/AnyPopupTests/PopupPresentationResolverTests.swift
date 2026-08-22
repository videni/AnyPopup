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
