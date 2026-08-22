import XCTest
@testable import AnyPopup

final class PopupPresentationStoreTests: XCTestCase {
    @MainActor
    func testPublishesResolvedAnchoredGeometryByPopupID() throws {
        let popupID = PopupID()
        let environment = PopupEnvironment(
            containerSize: CGSize(width: 500, height: 500),
            safeArea: .init(),
            keyboardOcclusionHeight: 0,
            accessibilityReduceMotion: false
        )
        let presentation = try PopupPresentationResolver.resolve(
            config: AnchoredPopupConfig()
                .size(width: .fixed(200), height: .fixed(100)),
            environment: environment,
            contentSize: .zero,
            anchorFrame: CGRect(x: 450, y: 40, width: 40, height: 40)
        )
        let plan = PopupLayoutPlan(
            items: [PopupLayoutItem(id: popupID, presentation: presentation)],
            backdrops: [],
            shieldPlacements: [],
            interactionRegions: [],
            failures: []
        )
        let store = PopupPresentationStore()

        store.publish(plan)

        XCTAssertEqual(store.anchoredGeometry(for: popupID), presentation.anchoredGeometry)

        store.publish(.init(
            items: [],
            backdrops: [],
            shieldPlacements: [],
            interactionRegions: [],
            failures: []
        ))
        XCTAssertNil(store.anchoredGeometry(for: popupID))
    }
}
