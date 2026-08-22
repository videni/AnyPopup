import SwiftUI
import XCTest
@testable import AnyPopup

@MainActor
final class PopupIdentityTests: XCTestCase {
    func testResponsiveRelayoutKeepsPopupIdentity() {
        let config = ContainerPopupConfig
            .center(
                CenterPopupConfig().size(width: .fixed(400), height: .fixed(300))
            )
            .when(
                .containerWidthLessThan(600),
                use: .bottom(
                    BottomPopupConfig().size(width: .fill, height: .fixed(300))
                )
            )
        let popup = AnyPopup(IdentityPopup(config: config))
        let contentSizes = [popup.id: CGSize(width: 400, height: 300)]

        let regular = PopupLayoutPlan.resolve(
            popups: [popup],
            environment: identityEnvironment(width: 1_000, height: 800),
            contentSizes: contentSizes
        )
        let compact = PopupLayoutPlan.resolve(
            popups: [popup],
            environment: identityEnvironment(width: 500, height: 800),
            contentSizes: contentSizes
        )

        XCTAssertEqual(regular.items.map(\.id), [popup.id])
        XCTAssertEqual(compact.items.map(\.id), [popup.id])
        XCTAssertNotEqual(
            regular.items.first?.presentation.frame,
            compact.items.first?.presentation.frame
        )
    }
}

private struct IdentityPopup: Popup {
    let config: ContainerPopupConfig

    var popupConfig: ContainerPopupConfig { config }

    var body: some View {
        Color.clear
    }
}

private func identityEnvironment(width: CGFloat, height: CGFloat) -> PopupEnvironment {
    PopupEnvironment(
        containerSize: CGSize(width: width, height: height),
        safeArea: EdgeInsets(),
        keyboardOcclusionHeight: 0,
        accessibilityReduceMotion: false
    )
}
