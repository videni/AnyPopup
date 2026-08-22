import SwiftUI
import XCTest
@testable import AnyPopup

@MainActor
final class PopupStackTests: XCTestCase {
    func testRemovingMiddlePopupRemovesItsSuffix() {
        let stack = PopupStack(id: .shared)
        let a = AnyPopup(StackTestPopup(name: "A").setCustomID("A"))
        let b = AnyPopup(StackTestPopup(name: "B").setCustomID("B"))
        let c = AnyPopup(StackTestPopup(name: "C").setCustomID("C"))
        _ = stack.insert(a)
        _ = stack.insert(b)
        _ = stack.insert(c)

        let mutation = stack.removePopupAndAbove(b.id)

        XCTAssertEqual(stack.popups.map(\.id), [a.id])
        XCTAssertEqual(mutation.removed.map(\.id), [b.id, c.id])
    }

    func testLifecycleCallbacksFireExactlyOnceForEachMutation() {
        let recorder = LifecycleRecorder()
        let stack = PopupStack(id: .shared)
        let a = AnyPopup(LifecyclePopup(name: "A", recorder: recorder).setCustomID("A"))
        let b = AnyPopup(LifecyclePopup(name: "B", recorder: recorder).setCustomID("B"))
        let c = AnyPopup(LifecyclePopup(name: "C", recorder: recorder).setCustomID("C"))
        _ = stack.insert(a)
        _ = stack.insert(b)
        _ = stack.insert(c)

        _ = stack.removePopupAndAbove(b.id)

        XCTAssertEqual(recorder.focused, ["A", "B", "C", "A"])
        XCTAssertEqual(recorder.dismissed, ["C", "B"])
    }

    func testDefaultTypeIsUniqueButCustomIDsPermitMultipleInstances() {
        let stack = PopupStack(id: .shared)
        let first = AnyPopup(StackTestPopup(name: "first"))
        let duplicate = AnyPopup(StackTestPopup(name: "duplicate"))
        let customA = AnyPopup(StackTestPopup(name: "A").setCustomID("A"))
        let customB = AnyPopup(StackTestPopup(name: "B").setCustomID("B"))

        XCTAssertNotNil(stack.insert(first).inserted)
        XCTAssertNil(stack.insert(duplicate).inserted)
        XCTAssertNotNil(stack.insert(customA).inserted)
        XCTAssertNotNil(stack.insert(customB).inserted)
        XCTAssertEqual(stack.popups.map(\.id), [first.id, customA.id, customB.id])
    }

    func testRemoveAllExcludingCustomIDsPreservesOriginalOrder() {
        let stack = PopupStack(id: .shared)
        let a = AnyPopup(StackTestPopup(name: "A").setCustomID("A"))
        let b = AnyPopup(StackTestPopup(name: "B").setCustomID("B"))
        let c = AnyPopup(StackTestPopup(name: "C").setCustomID("C"))
        _ = stack.insert(a)
        _ = stack.insert(b)
        _ = stack.insert(c)

        let mutation = stack.removeAll(excluding: ["A", "C"])

        XCTAssertEqual(stack.popups.map(\.id), [a.id, c.id])
        XCTAssertEqual(mutation.removed.map(\.id), [b.id])
        XCTAssertNil(mutation.focused)
    }
}

private struct StackTestPopup: Popup {
    let name: String
    let popupConfig = ContainerPopupConfig.center()

    var body: some View {
        Text(name)
    }
}

@MainActor
private final class LifecycleRecorder {
    var focused: [String] = []
    var dismissed: [String] = []
}

private struct LifecyclePopup: Popup {
    let name: String
    let recorder: LifecycleRecorder
    let popupConfig = ContainerPopupConfig.center()

    var body: some View {
        Text(name)
    }

    func onFocus() {
        recorder.focused.append(name)
    }

    func onDismiss() {
        recorder.dismissed.append(name)
    }
}
