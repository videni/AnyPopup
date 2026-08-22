import SwiftUI
import XCTest
@testable import AnyPopup

@MainActor
final class PopupCommandTests: XCTestCase {
    func testContainerPresentAndDismissCommandsUseRegisteredStack() async {
        let stackID = PopupStackID("command-\(UUID().uuidString)")
        let sceneID = "scene-\(UUID().uuidString)"
        let stack = PopupStack(id: stackID)
        PopupStackRegistry.shared.register(stack, sceneSessionID: sceneID)
        defer { PopupStackRegistry.shared.unregister(sceneSessionID: sceneID, popupStackID: stackID) }

        await CommandContainerPopup().setCustomID("A").present(popupStackID: stackID)
        await CommandContainerPopup().setCustomID("B").present(popupStackID: stackID)
        await CommandContainerPopup().setCustomID("C").present(popupStackID: stackID)
        await dismissPopup("B", popupStackID: stackID)

        XCTAssertEqual(stack.popups.compactMap(\.customID), ["A"])

        await dismissPopup(CommandContainerPopup.self, popupStackID: stackID)

        XCTAssertTrue(stack.popups.isEmpty)
    }

    func testAnchoredCommandsPreserveTrackedAndStaticSources() async {
        let stackID = PopupStackID("anchor-command-\(UUID().uuidString)")
        let sceneID = "scene-\(UUID().uuidString)"
        let stack = PopupStack(id: stackID)
        PopupStackRegistry.shared.register(stack, sceneSessionID: sceneID)
        defer { PopupStackRegistry.shared.unregister(sceneSessionID: sceneID, popupStackID: stackID) }
        let frame = CGRect(x: 10, y: 20, width: 30, height: 40)

        await CommandAnchoredPopup().present(
            anchoredTo: "menu",
            customID: "tracked",
            popupStackID: stackID
        )
        await CommandAnchoredPopup().present(
            anchoredTo: frame,
            customID: "static",
            popupStackID: stackID
        )
        await CommandAnchoredPopup()
            .setCustomID("wrapped")
            .present(anchoredTo: "wrapped-anchor", popupStackID: stackID)

        XCTAssertEqual(
            stack.popups.map(\.anchorSource),
            [.tracked("menu"), .frame(frame), .tracked("wrapped-anchor")]
        )
        XCTAssertEqual(stack.popups.map(\.customID), ["tracked", "static", "wrapped"])
    }

    func testStaleTimerIdentityDoesNotDismissReplacementWithSameCustomID() {
        let scheduler = ManualDismissScheduler()
        let registry = PopupStackRegistry(dismissScheduler: scheduler)
        let stackID = PopupStackID("timer")
        let sceneID = "scene"
        let stack = PopupStack(id: stackID)
        registry.register(stack, sceneSessionID: sceneID)
        let first = AnyPopup(
            CommandContainerPopup()
                .setCustomID("menu")
                .dismissAfter(1)
        )
        _ = registry.insert(first, sceneSessionID: sceneID, popupStackID: stackID)
        let staleAction = scheduler.action(for: first.id)
        _ = registry.removePopupAndAbove(
            first.id,
            sceneSessionID: sceneID,
            popupStackID: stackID
        )
        let replacement = AnyPopup(
            CommandContainerPopup()
                .setCustomID("menu")
                .dismissAfter(1)
        )
        _ = registry.insert(replacement, sceneSessionID: sceneID, popupStackID: stackID)

        staleAction?()

        XCTAssertEqual(stack.popups.map(\.id), [replacement.id])

        scheduler.action(for: replacement.id)?()

        XCTAssertTrue(stack.popups.isEmpty)
    }

    func testRegistryRequiresUniqueOrExplicitlyActiveScene() {
        let registry = PopupStackRegistry(dismissScheduler: ManualDismissScheduler())
        let stackID = PopupStackID("shared-in-two-scenes")
        let firstStack = PopupStack(id: stackID)
        let secondStack = PopupStack(id: stackID)
        registry.register(firstStack, sceneSessionID: "S1")
        registry.register(secondStack, sceneSessionID: "S2")
        let popup = AnyPopup(CommandContainerPopup())

        let ambiguousMutation = registry.insert(popup, popupStackID: stackID)

        XCTAssertNil(ambiguousMutation.inserted)
        XCTAssertEqual(registry.lastResolutionError, .ambiguous(stackID))

        registry.setActiveSceneSessionID("S2")
        let activeMutation = registry.insert(popup, popupStackID: stackID)

        XCTAssertEqual(activeMutation.inserted?.id, popup.id)
        XCTAssertTrue(firstStack.popups.isEmpty)
        XCTAssertEqual(secondStack.popups.map(\.id), [popup.id])

        registry.setActiveSceneSessionID("missing-scene")
        let missingMutation = registry.insert(
            AnyPopup(CommandContainerPopup().setCustomID("other")),
            popupStackID: stackID
        )

        XCTAssertNil(missingMutation.inserted)
        XCTAssertEqual(registry.lastResolutionError, .missing(stackID))
        XCTAssertTrue(firstStack.popups.isEmpty)
        XCTAssertEqual(secondStack.popups.map(\.id), [popup.id])
    }
}

private struct CommandContainerPopup: Popup {
    let popupConfig = ContainerPopupConfig.center()

    var body: some View {
        Text("Container")
    }
}

private struct CommandAnchoredPopup: Popup {
    let popupConfig = AnchoredPopupConfig()

    var body: some View {
        Text("Anchored")
    }
}

@MainActor
private final class ManualDismissScheduler: PopupDismissScheduling {
    private var actions: [PopupID: @MainActor () -> Void] = [:]

    func schedule(
        popupID: PopupID,
        after seconds: TimeInterval,
        action: @escaping @MainActor () -> Void
    ) {
        actions[popupID] = action
    }

    func cancel(popupID: PopupID) {}

    func action(for popupID: PopupID) -> (@MainActor () -> Void)? {
        actions[popupID]
    }
}
