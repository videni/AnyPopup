import SwiftUI
import XCTest
@testable import AnyPopup

final class PopupConfigurationTests: XCTestCase {
    func testCenterBuiltInConfigurationIsComplete() {
        let presentation = ContainerPopupConfig.center().defaultPresentation

        guard case let .center(config) = presentation else {
            return XCTFail("Expected center presentation")
        }
        XCTAssertEqual(config.size, .content)
        XCTAssertEqual(config.corners, .all(radius: 24))
        XCTAssertEqual(config.backdrop, .color(.black, opacity: 0.5))
        XCTAssertEqual(config.insertionTransition, .scaleAndOpacity)
        XCTAssertEqual(config.removalTransition, .scaleAndOpacity)
        XCTAssertEqual(config.keyboardAvoidance, .moveIntoVisibleRegion)
        XCTAssertEqual(config.outsideInteraction, .consume)
    }

    func testTopBuiltInConfigurationIsComplete() {
        let presentation = ContainerPopupConfig.top().defaultPresentation

        guard case let .top(config) = presentation else {
            return XCTFail("Expected top presentation")
        }
        XCTAssertEqual(config.size, .content)
        XCTAssertEqual(config.corners, .all(radius: 40))
        XCTAssertEqual(config.insertionTransition, .move(from: .top))
        XCTAssertEqual(config.removalTransition, .move(to: .top))
        XCTAssertEqual(config.drag.dismissalThreshold, 1.0 / 3.0, accuracy: 0.0001)
        XCTAssertTrue(config.drag.isEnabled)
        XCTAssertEqual(config.detents, [.large, .fullscreen])
    }

    func testBottomBuiltInConfigurationIsComplete() {
        let presentation = ContainerPopupConfig.bottom().defaultPresentation

        guard case let .bottom(config) = presentation else {
            return XCTFail("Expected bottom presentation")
        }
        XCTAssertEqual(config.size, .content)
        XCTAssertEqual(config.insertionTransition, .move(from: .bottom))
        XCTAssertEqual(config.removalTransition, .move(to: .bottom))
        XCTAssertEqual(config.drag.direction, .down)
        XCTAssertEqual(config.keyboardAvoidance, .respectVisibleBottom)
    }

    func testAnchoredBuiltInConfigurationIsComplete() {
        let config = AnchoredPopupConfig()

        XCTAssertEqual(config.sourceAnchor, .bottom)
        XCTAssertEqual(config.popupAnchor, .top)
        XCTAssertEqual(config.offset, .zero)
        XCTAssertEqual(config.screenAvoidance, .init(edges: .horizontal, padding: 16))
        XCTAssertEqual(config.insertionTransition, .opacity)
        XCTAssertEqual(config.removalTransition, .opacity)
        XCTAssertEqual(config.outsideInteraction, .dismissTop)
    }

    func testCommonCapabilitiesComposeWithoutChangingDomain() {
        let config = AnchoredPopupConfig()
            .size(width: .fixed(280), height: .content)
            .corners(.all(radius: 18))
            .backdrop(.none)
            .outsideInteraction(.passThrough)

        XCTAssertEqual(config.size, .dimensions(width: .fixed(280), height: .content))
        XCTAssertEqual(config.corners, .all(radius: 18))
        XCTAssertEqual(config.backdrop, .none)
        XCTAssertEqual(config.outsideInteraction, .passThrough)
    }
}
