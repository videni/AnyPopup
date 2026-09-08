import SwiftUI
import XCTest
@testable import AnyPopup

@MainActor
final class EnvironmentBridgeTests: XCTestCase {
    func testViewportDoesNotDoubleCountKeyboardExpandedSwiftUISafeArea() {
        let viewport = PopupViewport(
            containerSize: CGSize(width: 1_194, height: 834),
            systemSafeArea: EdgeInsets(
                top: 0,
                leading: 0,
                bottom: 20,
                trailing: 0
            ),
            keyboardOcclusionHeight: 408
        )

        let environment = viewport.environment(reduceMotion: false)

        XCTAssertEqual(environment.safeArea.bottom, 20)
        XCTAssertEqual(environment.keyboardOcclusionHeight, 408)
        XCTAssertEqual(environment.availableHeight, 406)
    }

    func testSceneGeometryAddsSafeAreaBackToFullContainerSize() {
        let size = PopupSceneGeometry.fullContainerSize(
            contentSize: CGSize(width: 780, height: 550),
            safeArea: EdgeInsets(top: 20, leading: 10, bottom: 30, trailing: 10)
        )

        XCTAssertEqual(size, CGSize(width: 800, height: 600))
    }

    func testBridgeSynchronizesSwiftUIEnvironmentValues() {
        let bridge = PopupEnvironmentBridge()

        bridge.update(
            locale: Locale(identifier: "zh-Hans"),
            layoutDirection: .rightToLeft,
            colorScheme: .dark,
            dynamicTypeSize: .accessibility3,
            reduceMotion: true
        )

        XCTAssertEqual(bridge.locale.identifier, "zh-Hans")
        XCTAssertEqual(bridge.layoutDirection, .rightToLeft)
        XCTAssertEqual(bridge.colorScheme, .dark)
        XCTAssertEqual(bridge.dynamicTypeSize, .accessibility3)
        XCTAssertTrue(bridge.reduceMotion)
    }

    func testBridgeBuildsGeometryEnvironmentWithoutGlobalScreenState() {
        let bridge = PopupEnvironmentBridge()
        bridge.update(
            locale: Locale(identifier: "en"),
            layoutDirection: .leftToRight,
            colorScheme: nil,
            dynamicTypeSize: .large,
            reduceMotion: true
        )

        let environment = bridge.popupEnvironment(
            containerSize: CGSize(width: 800, height: 600),
            safeArea: EdgeInsets(top: 20, leading: 10, bottom: 30, trailing: 10),
            keyboardOcclusionHeight: 200
        )

        XCTAssertEqual(environment.containerSize, CGSize(width: 800, height: 600))
        XCTAssertEqual(environment.availableWidth, 780)
        XCTAssertEqual(environment.availableHeight, 350)
        XCTAssertTrue(environment.accessibilityReduceMotion)
    }

    func testKeyboardManagerHookRunsOncePerScene() {
        let integration = KeyboardManagerIntegration()
        var invocationCount = 0

        XCTAssertTrue(integration.installOnce(sceneSessionID: "S1") {
            invocationCount += 1
        })
        XCTAssertFalse(integration.installOnce(sceneSessionID: "S1") {
            invocationCount += 1
        })
        XCTAssertTrue(integration.installOnce(sceneSessionID: "S2") {
            invocationCount += 1
        })

        XCTAssertEqual(invocationCount, 2)
    }
}
