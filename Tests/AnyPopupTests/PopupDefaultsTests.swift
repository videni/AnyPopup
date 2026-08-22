import SwiftUI
import XCTest
@testable import AnyPopup

final class PopupDefaultsTests: XCTestCase {
    func testStackDefaultOverridesBuiltInValue() {
        let defaults = PopupDefaults()
            .center { $0.corners(.all(radius: 12)) }
        let resolved = ContainerPopupConfig.center().resolve(
            in: environment(width: 1_000),
            defaults: defaults
        )

        guard case let .center(config) = resolved.presentation else {
            return XCTFail("Expected center presentation")
        }
        XCTAssertEqual(config.corners, .all(radius: 12))
    }

    func testPopupExplicitValueOverridesStackDefaultWhenEqualToBuiltInValue() {
        let defaults = PopupDefaults()
            .center { $0.corners(.all(radius: 12)) }
        let popup = ContainerPopupConfig.center(
            CenterPopupConfig().corners(.all(radius: 24))
        )
        let resolved = popup.resolve(
            in: environment(width: 1_000),
            defaults: defaults
        )

        guard case let .center(config) = resolved.presentation else {
            return XCTFail("Expected center presentation")
        }
        XCTAssertEqual(config.corners, .all(radius: 24))
    }

    func testVerticalDefaultsOnlyChangeTopAndBottom() {
        let defaults = PopupDefaults()
            .vertical {
                $0.corners(.all(radius: 18))
                    .drag(isEnabled: false)
            }

        XCTAssertEqual(defaults.center.corners, .all(radius: 24))
        XCTAssertEqual(defaults.top.corners, .all(radius: 18))
        XCTAssertEqual(defaults.bottom.corners, .all(radius: 18))
        XCTAssertFalse(defaults.top.drag.isEnabled)
        XCTAssertFalse(defaults.bottom.drag.isEnabled)
    }
}

private extension PopupDefaultsTests {
    func environment(width: CGFloat) -> PopupEnvironment {
        PopupEnvironment(
            containerSize: CGSize(width: width, height: 800),
            safeArea: EdgeInsets(),
            keyboardOcclusionHeight: 0,
            accessibilityReduceMotion: false
        )
    }
}
