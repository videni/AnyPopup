import SwiftUI
import XCTest
@testable import AnyPopup

@MainActor
final class PopupRenderEntryTests: XCTestCase {
    func testPopupKeepsOneRenderEntryWhenItMovesFromActiveToDismissing() {
        let popup = AnyPopup(RenderEntryPopup())
        let snapshot = makeSnapshot(for: popup)

        let active = PopupRenderEntry.resolve(active: [popup], dismissing: [])
        let dismissing = PopupRenderEntry.resolve(active: [], dismissing: [snapshot])

        XCTAssertEqual(active.map(\.id), [popup.id])
        XCTAssertEqual(active.first?.phase, .active)
        XCTAssertEqual(dismissing.map(\.id), [popup.id])
        XCTAssertEqual(dismissing.first?.phase, .awaitingDeparture)
    }

    func testDismissalEntryReplacesSameActiveIdentityWithoutDuplication() {
        let popup = AnyPopup(RenderEntryPopup())
        let snapshot = makeSnapshot(for: popup)

        let entries = PopupRenderEntry.resolve(active: [popup], dismissing: [snapshot])

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.id, popup.id)
        XCTAssertEqual(entries.first?.phase, .awaitingDeparture)
    }

    func testDepartingSnapshotProducesDepartingRenderPhase() {
        let popup = AnyPopup(RenderEntryPopup())
        var snapshot = makeSnapshot(for: popup)
        snapshot.markDeparting()

        let entries = PopupRenderEntry.resolve(active: [], dismissing: [snapshot])

        XCTAssertEqual(entries.first?.phase, .departing)
    }
}

@MainActor
private func makeSnapshot(for popup: AnyPopup) -> PopupDismissalSnapshot {
    let environment = PopupEnvironment(
        containerSize: CGSize(width: 600, height: 900),
        safeArea: EdgeInsets(),
        keyboardOcclusionHeight: 0,
        accessibilityReduceMotion: false
    )
    let presentation = PopupPresentationResolver.resolve(
        config: ContainerPopupConfig.center(
            CenterPopupConfig().size(width: .fixed(200), height: .fixed(100))
        ),
        environment: environment,
        contentSize: CGSize(width: 200, height: 100)
    )
    return PopupDismissalSnapshot(
        popup: popup,
        presentation: presentation,
        batchID: PopupDismissalBatchID()
    )
}

private struct RenderEntryPopup: Popup {
    let popupConfig = ContainerPopupConfig.center(
        CenterPopupConfig().size(width: .fixed(200), height: .fixed(100))
    )

    var body: some View {
        Text("Popup")
    }
}
