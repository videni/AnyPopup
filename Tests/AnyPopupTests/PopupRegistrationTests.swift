import AppKit
import SwiftUI
import XCTest
@testable import AnyPopup

@MainActor
final class PopupRegistrationTests: XCTestCase {
    func testTrackAnchorKeepsLastValidFrameAcrossTransientZeroGeometry() {
        let sceneSessionID = "transient-zero-anchor-test"
        let stackID = PopupStackID("transient-zero-anchor-stack")
        let key = AnchorRegistry.Key(
            sceneSessionID: sceneSessionID,
            popupStackID: stackID,
            anchorID: "late-anchor"
        )
        AnchorRegistry.shared.removeAll(sceneSessionID: sceneSessionID)
        defer {
            AnchorRegistry.shared.removeAll(sceneSessionID: sceneSessionID)
        }

        let store = LateAnchorContextStore()
        store.context = PopupAnchorRegistrationContext(
            sceneSessionID: sceneSessionID,
            popupStackID: stackID,
            sourceCoordinateSpace: .popupView,
            popupCoordinateSpace: .popupView
        )
        let hostingController = NSHostingController(
            rootView: LateAnchorContextHarness(store: store)
        )
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 300, height: 300)
        let window = NSWindow(
            contentRect: hostingController.view.frame,
            styleMask: [],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hostingController
        window.orderFront(nil)
        hostingController.view.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))

        XCTAssertEqual(AnchorRegistry.shared.frame(for: key)?.size, CGSize(width: 36, height: 36))

        store.anchorSize = .zero
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        hostingController.view.layoutSubtreeIfNeeded()

        XCTAssertEqual(AnchorRegistry.shared.frame(for: key)?.size, CGSize(width: 36, height: 36))
    }

    func testTrackAnchorRegistersExistingFrameWhenContextArrivesAfterGeometry() {
        let sceneSessionID = "late-anchor-context-test"
        let stackID = PopupStackID("late-anchor-context-stack")
        let key = AnchorRegistry.Key(
            sceneSessionID: sceneSessionID,
            popupStackID: stackID,
            anchorID: "late-anchor"
        )
        AnchorRegistry.shared.removeAll(sceneSessionID: sceneSessionID)
        defer {
            AnchorRegistry.shared.removeAll(sceneSessionID: sceneSessionID)
        }

        let store = LateAnchorContextStore()
        let hostingController = NSHostingController(
            rootView: LateAnchorContextHarness(store: store)
        )
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 300, height: 300)
        let window = NSWindow(
            contentRect: hostingController.view.frame,
            styleMask: [],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hostingController
        window.orderFront(nil)
        hostingController.view.layoutSubtreeIfNeeded()

        XCTAssertNil(AnchorRegistry.shared.frame(for: key))

        store.context = PopupAnchorRegistrationContext(
            sceneSessionID: sceneSessionID,
            popupStackID: stackID,
            sourceCoordinateSpace: .popupView,
            popupCoordinateSpace: .popupView
        )
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        hostingController.view.layoutSubtreeIfNeeded()

        let frame = AnchorRegistry.shared.frame(for: key)
        XCTAssertEqual(frame?.size, CGSize(width: 36, height: 36))
    }
}

@MainActor
private final class LateAnchorContextStore: ObservableObject {
    @Published var context: PopupAnchorRegistrationContext?
    @Published var anchorSize = CGSize(width: 36, height: 36)
}

private struct LateAnchorContextHarness: View {
    @ObservedObject var store: LateAnchorContextStore

    var body: some View {
        Color.clear
            .frame(width: store.anchorSize.width, height: store.anchorSize.height)
            .trackAnchor("late-anchor")
            .popupAnchorRegistrationContext(store.context)
    }
}
