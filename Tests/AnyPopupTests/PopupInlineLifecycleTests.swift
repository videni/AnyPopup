import XCTest
import SwiftUI
@testable import AnyPopup

@MainActor
final class PopupInlineLifecycleTests: XCTestCase {
    func testEmptyOrPassThroughPopupDoesNotCaptureUnderlyingButton() {
        XCTAssertFalse(PopupShield.capturesTouches(topPolicy: nil, hasDismissalSnapshots: false))
        XCTAssertFalse(PopupShield.capturesTouches(topPolicy: .passThrough, hasDismissalSnapshots: false))
        XCTAssertTrue(PopupShield.capturesTouches(topPolicy: .dismissTop, hasDismissalSnapshots: false))
        XCTAssertTrue(PopupShield.capturesTouches(topPolicy: nil, hasDismissalSnapshots: true))
    }

    func testRemountDoesNotClearSameStackAndOldUnmountCannotRemoveNewOwner() {
        let registry = PopupStackRegistry()
        let stack = PopupStack(id: PopupStackID("inline-lifecycle"))
        let old = UUID(), next = UUID()
        registry.registerInline(stack, sceneSessionID: "scene", ownerID: old)
        registry.insert(AnyPopup(InlineLifecyclePopup()), sceneSessionID: "scene", popupStackID: stack.id)
        registry.registerInline(stack, sceneSessionID: "scene", ownerID: next)
        XCTAssertEqual(stack.popups.count, 1)
        registry.unregisterInline(sceneSessionID: "scene", popupStackID: stack.id, ownerID: old)
        XCTAssertTrue(registry.stack(sceneSessionID: "scene", popupStackID: stack.id) === stack)
        XCTAssertEqual(stack.popups.count, 1)
        registry.unregisterInline(sceneSessionID: "scene", popupStackID: stack.id, ownerID: next)
        XCTAssertNil(registry.stack(sceneSessionID: "scene", popupStackID: stack.id))
        XCTAssertTrue(stack.popups.isEmpty)
    }
}

private struct InlineLifecyclePopup: Popup {
    let popupConfig = ContainerPopupConfig.center()
    var body: some View { Color.clear }
}
