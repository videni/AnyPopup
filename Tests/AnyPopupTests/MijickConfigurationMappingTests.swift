import SwiftUI
import XCTest
@testable import AnyPopup

final class MijickConfigurationMappingTests: XCTestCase {
    func testCenterMapsPaddingCornersBackgroundBackdropAndOutsideInteraction() {
        let config = CenterPopupConfig()
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .corners(.all(radius: 18))
            .background(.color(.red))
            .backdrop(.color(.black, opacity: 0.25))
            .outsideInteraction(.dismissTop)

        XCTAssertEqual(
            config.padding,
            EdgeInsets(top: 12, leading: 24, bottom: 12, trailing: 24)
        )
        XCTAssertEqual(config.corners, .all(radius: 18))
        XCTAssertEqual(config.background, .color(.red))
        XCTAssertEqual(config.backdrop, .color(.black, opacity: 0.25))
        XCTAssertEqual(config.outsideInteraction, .dismissTop)
    }

    func testCenterDefaultHorizontalPaddingConstrainsFrame() {
        let environment = popupMappingEnvironment(width: 300, height: 600)

        let presentation = PopupPresentationResolver.resolve(
            config: .center(
                CenterPopupConfig().size(width: .fill, height: .fixed(100))
            ),
            environment: environment,
            contentSize: CGSize(width: 500, height: 100)
        )

        XCTAssertEqual(presentation.frame, CGRect(x: 16, y: 250, width: 268, height: 100))
    }

    func testVerticalMapsPaddingSafeAreaDragDetentsAndStackAppearance() {
        let top = TopPopupConfig()
            .padding(.top, 20)
            .padding(.horizontal, 12)
            .safeArea(.ignored)
            .drag(isEnabled: true, activationArea: 44, dismissalThreshold: 0.25)
            .detents([.fixed(240), .fraction(0.7), .large, .fullscreen])
            .stackAppearance(.flat)
        let bottom = BottomPopupConfig()
            .padding(.bottom, 24)
            .safeArea(.contained)
            .drag(isEnabled: false)
            .detents([.fixed(300)])

        XCTAssertEqual(top.padding.top, 20)
        XCTAssertEqual(top.padding.leading, 12)
        XCTAssertEqual(top.safeArea, .ignored)
        XCTAssertEqual(top.drag.activationArea, 44)
        XCTAssertEqual(top.drag.dismissalThreshold, 0.25)
        XCTAssertEqual(top.detents, [.fixed(240), .fraction(0.7), .large, .fullscreen])
        XCTAssertEqual(top.stackAppearance, .flat)
        XCTAssertEqual(bottom.padding.bottom, 24)
        XCTAssertEqual(bottom.safeArea, .contained)
        XCTAssertFalse(bottom.drag.isEnabled)
        XCTAssertEqual(bottom.detents, [.fixed(300)])
    }

    func testMijickNamedConveniencesMapToTypedPolicies() {
        let config = BottomPopupConfig()
            .popupHorizontalPadding(22)
            .popupTopPadding(10)
            .popupBottomPadding(18)
            .cornerRadius(14)
            .backgroundColor(.red)
            .overlayColor(.black.opacity(0.4))
            .transition(.opacity)
            .tapOutsideToDismissPopup(true)
            .ignoreSafeArea(edges: [.bottom])
            .enableDragGesture(true)
            .dragGestureAreaSize(48)
            .heightMode(.fraction(0.7))

        XCTAssertEqual(config.padding, EdgeInsets(top: 10, leading: 22, bottom: 18, trailing: 22))
        XCTAssertEqual(config.corners, .all(radius: 14))
        XCTAssertEqual(config.background, .color(.red))
        XCTAssertEqual(config.insertionTransition, .opacity)
        XCTAssertEqual(config.removalTransition, .opacity)
        XCTAssertEqual(config.outsideInteraction, .dismissTop)
        XCTAssertEqual(config.safeArea, .ignoring(.bottom))
        XCTAssertTrue(config.drag.isEnabled)
        XCTAssertEqual(config.drag.activationArea, 48)
        XCTAssertEqual(
            config.size,
            .dimensions(width: .content, height: .fraction(0.7))
        )
    }

    func testAnchoredMijickNamedConveniencesKeepAnchoredDomain() {
        let config = AnchoredPopupConfig()
            .originAnchor(.bottomRight)
            .popupAnchor(.topRight)
            .edgePadding(18, edges: .all)
            .tapOutsideBehavior(.passThrough)

        XCTAssertEqual(config.sourceAnchor, .bottomRight)
        XCTAssertEqual(config.popupAnchor, .topRight)
        XCTAssertEqual(config.screenAvoidance, .init(edges: .all, padding: 18))
        XCTAssertEqual(config.outsideInteraction, .passThrough)
    }

    func testContainerMapsLayoutTransitionWithoutChangingPopupIdentity() {
        let config = ContainerPopupConfig.center()
            .layoutTransition(.move(from: .bottom))

        let presentation = PopupPresentationResolver.resolve(
            config: config,
            environment: popupMappingEnvironment(width: 800, height: 600),
            contentSize: CGSize(width: 200, height: 100)
        )

        XCTAssertEqual(presentation.layoutTransition, .move(from: .bottom))
    }

    func testAnchoredMapsPaddingAnchorOffsetAvoidanceAndOutsideInteraction() throws {
        let config = AnchoredPopupConfig()
            .padding(.horizontal, 8)
            .anchor(source: .bottomRight, popup: .topRight)
            .offset(x: 4, y: 6)
            .screenAvoidance(edges: .all, padding: 12)
            .outsideInteraction(.passThrough)

        let presentation = try PopupPresentationResolver.resolve(
            config: config,
            environment: popupMappingEnvironment(width: 400, height: 500),
            contentSize: CGSize(width: 120, height: 80),
            anchorFrame: CGRect(x: 360, y: 100, width: 20, height: 20)
        )

        XCTAssertEqual(config.padding.leading, 8)
        XCTAssertEqual(config.sourceAnchor, .bottomRight)
        XCTAssertEqual(config.popupAnchor, .topRight)
        XCTAssertEqual(config.offset, CGSize(width: 4, height: 6))
        XCTAssertEqual(config.screenAvoidance, .init(edges: .all, padding: 12))
        XCTAssertEqual(presentation.outsideInteraction, .passThrough)
        XCTAssertLessThanOrEqual(presentation.frame.maxX, 380)
    }

    func testAnchoredResponsiveRuleStaysInsideAnchoredDomain() {
        let regular = AnchoredPopupConfig()
            .size(width: .fixed(280), height: .content)
            .anchor(source: .bottom, popup: .top)
        let compact = AnchoredPopupConfig()
            .size(width: .fixed(200), height: .content)
            .anchor(source: .right, popup: .left)
        let responsive = regular.when(
            .availableWidthLessThan(500),
            use: compact
        )

        let regularResolved = responsive.resolve(
            in: popupMappingEnvironment(width: 800, height: 600)
        )
        let compactResolved = responsive.resolve(
            in: popupMappingEnvironment(width: 400, height: 600)
        )

        XCTAssertEqual(
            regularResolved.configuration.size,
            .dimensions(width: .fixed(280), height: .content)
        )
        XCTAssertEqual(regularResolved.configuration.sourceAnchor, .bottom)
        XCTAssertEqual(
            compactResolved.configuration.size,
            .dimensions(width: .fixed(200), height: .content)
        )
        XCTAssertEqual(compactResolved.configuration.sourceAnchor, .right)
        XCTAssertEqual(compactResolved.matchedRuleIndices, [0])
    }
}

private func popupMappingEnvironment(width: CGFloat, height: CGFloat) -> PopupEnvironment {
    PopupEnvironment(
        containerSize: CGSize(width: width, height: height),
        safeArea: EdgeInsets(),
        keyboardOcclusionHeight: 0,
        accessibilityReduceMotion: false
    )
}
