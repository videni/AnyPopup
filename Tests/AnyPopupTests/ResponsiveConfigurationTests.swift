import SwiftUI
import XCTest
@testable import AnyPopup

final class ResponsiveConfigurationTests: XCTestCase {
    func testLastMatchingRuleSelectsCompleteBranch() {
        let config = ContainerPopupConfig.center()
            .when(
                .containerWidthLessThan(800),
                use: .top(TopPopupConfig().corners(.all(radius: 30)))
            )
            .when(
                .containerWidthLessThan(600),
                use: .bottom(BottomPopupConfig().corners(.all(radius: 16)))
            )

        let resolved = config.resolve(in: environment(width: 500))

        XCTAssertEqual(resolved.kind, .bottom)
        XCTAssertEqual(resolved.matchedRuleIndices, [0, 1])
        guard case let .bottom(bottom) = resolved.presentation else {
            return XCTFail("Expected bottom presentation")
        }
        XCTAssertEqual(bottom.corners, .all(radius: 16))
    }

    func testUnmatchedRuleDoesNotPatchDefaultBranch() {
        let config = ContainerPopupConfig.center(
            CenterPopupConfig().corners(.all(radius: 22))
        )
        .when(
            .containerWidthLessThan(600),
            use: .bottom(BottomPopupConfig().corners(.all(radius: 10)))
        )

        let resolved = config.resolve(in: environment(width: 700))

        XCTAssertEqual(resolved.kind, .center)
        XCTAssertTrue(resolved.matchedRuleIndices.isEmpty)
        guard case let .center(center) = resolved.presentation else {
            return XCTFail("Expected center presentation")
        }
        XCTAssertEqual(center.corners, .all(radius: 22))
    }

    func testKeyboardConditionUsesOcclusionInput() {
        let config = ContainerPopupConfig.center()
            .when(.keyboardVisible, use: .bottom(BottomPopupConfig()))

        XCTAssertEqual(
            config.resolve(in: environment(width: 700, keyboardOcclusionHeight: 300)).kind,
            .bottom
        )
        XCTAssertEqual(
            config.resolve(in: environment(width: 700, keyboardOcclusionHeight: 0)).kind,
            .center
        )
    }

    func testReduceMotionConditionUsesAccessibilityInput() {
        let config = ContainerPopupConfig.center()
            .when(.accessibilityReduceMotion, use: .top(TopPopupConfig()))

        XCTAssertEqual(
            config.resolve(in: environment(width: 700, reduceMotion: true)).kind,
            .top
        )
        XCTAssertEqual(
            config.resolve(in: environment(width: 700, reduceMotion: false)).kind,
            .center
        )
    }

    func testAvailableSizeConditionsUseSafeAreaAndKeyboardOcclusion() {
        let config = ContainerPopupConfig.center()
            .when(.availableWidthLessThan(600), use: .top(TopPopupConfig()))
            .when(.availableHeightLessThan(500), use: .bottom(BottomPopupConfig()))
        let environment = PopupEnvironment(
            containerSize: CGSize(width: 640, height: 800),
            safeArea: EdgeInsets(top: 20, leading: 30, bottom: 20, trailing: 30),
            keyboardOcclusionHeight: 300,
            accessibilityReduceMotion: false
        )

        let resolved = config.resolve(in: environment)

        XCTAssertEqual(environment.availableWidth, 580)
        XCTAssertEqual(environment.availableHeight, 460)
        XCTAssertEqual(resolved.kind, .bottom)
        XCTAssertEqual(resolved.matchedRuleIndices, [0, 1])
    }
}

private extension ResponsiveConfigurationTests {
    func environment(
        width: CGFloat,
        keyboardOcclusionHeight: CGFloat = 0,
        reduceMotion: Bool = false
    ) -> PopupEnvironment {
        PopupEnvironment(
            containerSize: CGSize(width: width, height: 800),
            safeArea: EdgeInsets(),
            keyboardOcclusionHeight: keyboardOcclusionHeight,
            accessibilityReduceMotion: reduceMotion
        )
    }
}
