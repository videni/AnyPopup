import SwiftUI
import XCTest
@testable import AnyPopup

@MainActor
final class MixedPopupStackTests: XCTestCase {
    func testMixedPopupsKeepInsertionOrderAndUseOneShield() {
        let center = AnyPopup(
            MixedContainerPopup(
                config: .center(CenterPopupConfig().size(width: .fixed(180), height: .fixed(120)))
            ).setCustomID("center")
        )
        let anchored = AnyPopup(
            MixedAnchoredPopup(),
            anchorSource: .frame(CGRect(x: 250, y: 100, width: 40, height: 30)),
            customIDOverride: "anchored"
        )
        let bottom = AnyPopup(
            MixedContainerPopup(
                config: .bottom(BottomPopupConfig().size(width: .fill, height: .fixed(220)))
            ).setCustomID("bottom")
        )

        let plan = PopupLayoutPlan.resolve(
            popups: [center, anchored, bottom],
            environment: popupEnvironment(width: 600, height: 900),
            contentSizes: [
                center.id: CGSize(width: 180, height: 120),
                anchored.id: CGSize(width: 140, height: 100),
                bottom.id: CGSize(width: 600, height: 220)
            ]
        )

        XCTAssertEqual(plan.items.map(\.id), [center.id, anchored.id, bottom.id])
        XCTAssertEqual(plan.shieldCount, 1)
    }

    func testEachPopupBackdropKeepsItsPopupIndex() {
        let first = AnyPopup(
            MixedContainerPopup(
                config: .center(
                    CenterPopupConfig().backdrop(.color(.black, opacity: 0.2))
                )
            ).setCustomID("first")
        )
        let second = AnyPopup(
            MixedContainerPopup(
                config: .bottom(
                    BottomPopupConfig().backdrop(.color(.red, opacity: 0.4))
                )
            ).setCustomID("second")
        )

        let plan = PopupLayoutPlan.resolve(
            popups: [first, second],
            environment: popupEnvironment(width: 600, height: 900),
            contentSizes: [
                first.id: CGSize(width: 200, height: 100),
                second.id: CGSize(width: 600, height: 200)
            ]
        )

        XCTAssertEqual(plan.backdrops.map(\.popupIndex), [0, 1])
    }
}

private struct MixedContainerPopup: Popup {
    let config: ContainerPopupConfig

    var popupConfig: ContainerPopupConfig { config }

    var body: some View {
        Color.clear
    }
}

private struct MixedAnchoredPopup: Popup {
    let popupConfig = AnchoredPopupConfig()

    var body: some View {
        Color.clear
    }
}

private func popupEnvironment(width: CGFloat, height: CGFloat) -> PopupEnvironment {
    PopupEnvironment(
        containerSize: CGSize(width: width, height: height),
        safeArea: EdgeInsets(),
        keyboardOcclusionHeight: 0,
        accessibilityReduceMotion: false
    )
}
