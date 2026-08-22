import SwiftUI
import XCTest
@testable import AnyPopup

@MainActor
final class PopupLifecycleTests: XCTestCase {
    func testDismissCommandWaitsAfterImmediateStackMutation() async {
        let stackID = PopupStackID("lifecycle-\(UUID().uuidString)")
        let sceneID = "scene-\(UUID().uuidString)"
        let coordinator = PopupDismissalCoordinator()
        let stack = PopupStack(id: stackID, dismissalCoordinator: coordinator)
        let popup = AnyPopup(LifecycleCommandPopup().setCustomID("popup"))
        stack.insert(popup)
        prepareLifecyclePresentation(popup: popup, coordinator: coordinator)
        PopupStackRegistry.shared.register(stack, sceneSessionID: sceneID)
        defer {
            PopupStackRegistry.shared.unregister(sceneSessionID: sceneID, popupStackID: stackID)
        }
        var commandReturned = false

        let command = Task { @MainActor in
            await dismissLastPopup(popupStackID: stackID)
            commandReturned = true
        }
        await Task.yield()

        XCTAssertTrue(stack.popups.isEmpty)
        XCTAssertFalse(commandReturned)

        coordinator.complete(identity: popup.id)
        await command.value

        XCTAssertTrue(commandReturned)
    }

    func testUnregisterCancelsPendingVisualCompletion() async {
        let stackID = PopupStackID("scene-close-\(UUID().uuidString)")
        let sceneID = "scene-\(UUID().uuidString)"
        let coordinator = PopupDismissalCoordinator()
        let stack = PopupStack(id: stackID, dismissalCoordinator: coordinator)
        let popup = AnyPopup(LifecycleCommandPopup())
        stack.insert(popup)
        prepareLifecyclePresentation(popup: popup, coordinator: coordinator)
        PopupStackRegistry.shared.register(stack, sceneSessionID: sceneID)
        let mutation = stack.removeLast()
        guard let batch = mutation.dismissalBatch else {
            return XCTFail("Expected dismissal batch")
        }
        var didComplete = false
        let waiter = Task { @MainActor in
            await batch.wait()
            didComplete = true
        }

        PopupStackRegistry.shared.unregister(sceneSessionID: sceneID, popupStackID: stackID)
        await waiter.value

        XCTAssertTrue(didComplete)
        XCTAssertTrue(coordinator.snapshots.isEmpty)
    }
}

@MainActor
private func prepareLifecyclePresentation(
    popup: AnyPopup,
    coordinator: PopupDismissalCoordinator
) {
    let environment = PopupEnvironment(
        containerSize: CGSize(width: 600, height: 900),
        safeArea: EdgeInsets(),
        keyboardOcclusionHeight: 0,
        accessibilityReduceMotion: false
    )
    let map = PopupInteractionMap()
    map.publish(PopupLayoutPlan.resolve(
        popups: [popup],
        environment: environment,
        contentSizes: [popup.id: CGSize(width: 200, height: 100)]
    ))
    coordinator.bindInteractionMap(map)
    coordinator.configure(isRenderingActive: true, reduceMotion: false)
}

private struct LifecycleCommandPopup: Popup {
    let popupConfig = ContainerPopupConfig.center(
        CenterPopupConfig().size(width: .fixed(200), height: .fixed(100))
    )

    var body: some View {
        Text("Popup")
    }
}
