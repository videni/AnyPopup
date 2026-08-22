import SwiftUI
import XCTest
@testable import AnyPopup

final class PopupInteractionRenderingTests: XCTestCase {
    func testVerticalTranslationUpdatesPresentationAndInteractionFrameTogether() {
        let id = PopupID()
        let input = PopupLayoutInput(
            id: id,
            configuration: .container(
                .bottom(BottomPopupConfig().size(width: .fixed(300), height: .fixed(200)))
            ),
            anchorFrame: nil,
            verticalTranslation: 75
        )

        let plan = PopupLayoutPlan.resolve(
            inputs: [input],
            environment: interactionEnvironment,
            contentSizes: [id: CGSize(width: 300, height: 200)],
            defaults: PopupDefaults()
        )

        XCTAssertEqual(plan.items[0].presentation.frame, CGRect(x: 150, y: 575, width: 300, height: 200))
        XCTAssertEqual(plan.interactionRegions[0].frame, plan.items[0].presentation.frame)
    }

    func testHeightOverrideKeepsBottomPopupAttachedToBottom() {
        let id = PopupID()
        let input = PopupLayoutInput(
            id: id,
            configuration: .container(.bottom(BottomPopupConfig())),
            anchorFrame: nil,
            heightOverride: 420
        )

        let plan = PopupLayoutPlan.resolve(
            inputs: [input],
            environment: interactionEnvironment,
            contentSizes: [id: CGSize(width: 300, height: 200)],
            defaults: PopupDefaults()
        )

        XCTAssertEqual(plan.items[0].presentation.frame.height, 420)
        XCTAssertEqual(plan.items[0].presentation.frame.maxY, 700)
    }

    func testStackAppearanceTransformsFrameAndPublishesOverlay() {
        let id = PopupID()
        let appearance = PopupStackItemAppearance(
            transform: PopupTransform(
                translation: CGSize(width: 0, height: -8),
                scale: 0.9
            ),
            opacity: 0.8,
            overlayOpacity: 0.2,
            zIndex: 0
        )
        let input = PopupLayoutInput(
            id: id,
            configuration: .container(
                .bottom(BottomPopupConfig().size(width: .fixed(300), height: .fixed(200)))
            ),
            anchorFrame: nil,
            stackAppearance: appearance
        )

        let plan = PopupLayoutPlan.resolve(
            inputs: [input],
            environment: interactionEnvironment,
            contentSizes: [id: CGSize(width: 300, height: 200)],
            defaults: PopupDefaults()
        )
        let presentation = plan.items[0].presentation

        XCTAssertEqual(presentation.frame, CGRect(x: 165, y: 502, width: 270, height: 180))
        XCTAssertEqual(presentation.opacity, 0.8)
        XCTAssertEqual(presentation.stackOverlayOpacity, 0.2)
        XCTAssertEqual(plan.interactionRegions[0].frame, presentation.frame)
    }
}

private let interactionEnvironment = PopupEnvironment(
    containerSize: CGSize(width: 600, height: 700),
    safeArea: EdgeInsets(),
    keyboardOcclusionHeight: 0,
    accessibilityReduceMotion: false
)
