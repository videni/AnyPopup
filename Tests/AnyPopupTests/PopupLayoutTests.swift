import SwiftUI
import XCTest
@testable import AnyPopup

@MainActor
final class PopupLayoutTests: XCTestCase {
    func testLayoutItemsAndInteractionRegionsUseSameFrames() {
        let first = AnyPopup(LayoutPopup().setCustomID("first"))
        let second = AnyPopup(LayoutPopup().setCustomID("second"))

        let plan = PopupLayoutPlan.resolve(
            popups: [first, second],
            environment: layoutEnvironment,
            contentSizes: [
                first.id: CGSize(width: 200, height: 100),
                second.id: CGSize(width: 240, height: 120)
            ]
        )

        XCTAssertEqual(plan.interactionRegions.map(\.id), plan.items.map(\.id))
        XCTAssertEqual(
            plan.interactionRegions.map(\.frame),
            plan.items.map(\.presentation.frame)
        )
    }

    func testMissingTrackedAnchorDoesNotPublishItemOrInteractionRegion() {
        let popup = AnyPopup(
            LayoutAnchoredPopup(),
            anchorSource: .tracked("missing")
        )

        let plan = PopupLayoutPlan.resolve(
            popups: [popup],
            environment: layoutEnvironment,
            contentSizes: [popup.id: CGSize(width: 120, height: 80)]
        )

        XCTAssertTrue(plan.items.isEmpty)
        XCTAssertTrue(plan.interactionRegions.isEmpty)
        XCTAssertEqual(plan.failures, [.init(id: popup.id, error: .missingAnchorFrame)])
        XCTAssertEqual(plan.shieldCount, 0)
    }

    func testInteractionMapPublishesExactLayoutPlanSnapshot() {
        let popup = AnyPopup(LayoutPopup())
        let plan = PopupLayoutPlan.resolve(
            popups: [popup],
            environment: layoutEnvironment,
            contentSizes: [popup.id: CGSize(width: 200, height: 100)]
        )
        let map = PopupInteractionMap()

        map.publish(plan)

        XCTAssertEqual(map.snapshot().regions, plan.interactionRegions)
        XCTAssertEqual(map.snapshot().topPolicy, plan.items.last?.presentation.outsideInteraction)
    }

    func testPopupViewMeasuresAndPublishesFrameInSameRenderPass() {
        let stack = PopupStack(id: .shared)
        let popup = AnyPopup(FixedLayoutPopup())
        stack.insert(popup)
        let map = PopupInteractionMap()
        let renderer = ImageRenderer(
            content: PopupView(
                popupStack: stack,
                sceneSessionID: "S1",
                environment: layoutEnvironment,
                interactionMap: map
            )
        )
        renderer.proposedSize = ProposedViewSize(layoutEnvironment.containerSize)

        XCTAssertNotNil(renderer.cgImage)
        XCTAssertEqual(
            map.snapshot().regions,
            [
                PopupInteractionRegion(
                    id: popup.id,
                    frame: CGRect(x: 200, y: 400, width: 200, height: 100)
                )
            ]
        )
    }
}

private struct LayoutPopup: Popup {
    let popupConfig = ContainerPopupConfig.center()

    var body: some View {
        Color.clear
    }
}

private struct LayoutAnchoredPopup: Popup {
    let popupConfig = AnchoredPopupConfig()

    var body: some View {
        Color.clear
    }
}

private struct FixedLayoutPopup: Popup {
    let popupConfig = ContainerPopupConfig.center(
        CenterPopupConfig().size(width: .fixed(200), height: .fixed(100))
    )

    var body: some View {
        Text("Popup")
    }
}

private let layoutEnvironment = PopupEnvironment(
    containerSize: CGSize(width: 600, height: 900),
    safeArea: EdgeInsets(top: 20, leading: 10, bottom: 20, trailing: 10),
    keyboardOcclusionHeight: 0,
    accessibilityReduceMotion: false
)
