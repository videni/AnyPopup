import SwiftUI
import XCTest
@testable import AnyPopup

@MainActor
final class PopupDismissalCoordinatorTests: XCTestCase {
    func testStackMutatesBeforeDismissalBatchCompletes() async {
        let coordinator = PopupDismissalCoordinator()
        let stack = PopupStack(id: .shared, dismissalCoordinator: coordinator)
        let popup = AnyPopup(DismissalPopup().setCustomID("popup"))
        stack.insert(popup)
        preparePresentation(for: [popup], coordinator: coordinator)

        let mutation = stack.removeLast()

        XCTAssertTrue(stack.popups.isEmpty)
        XCTAssertEqual(coordinator.snapshots.map(\.id), [popup.id])
        guard let batch = mutation.dismissalBatch else {
            return XCTFail("Expected dismissal batch")
        }
        var didComplete = false
        let waiter = Task { @MainActor in
            await batch.wait()
            didComplete = true
        }
        await Task.yield()
        XCTAssertFalse(didComplete)

        coordinator.complete(identity: popup.id)
        await waiter.value

        XCTAssertTrue(didComplete)
        XCTAssertTrue(coordinator.snapshots.isEmpty)
    }

    func testSuffixBatchWaitsForEverySnapshot() async {
        let coordinator = PopupDismissalCoordinator()
        let stack = PopupStack(id: .shared, dismissalCoordinator: coordinator)
        let a = AnyPopup(DismissalPopup().setCustomID("A"))
        let b = AnyPopup(DismissalPopup().setCustomID("B"))
        let c = AnyPopup(DismissalPopup().setCustomID("C"))
        for popup in [a, b, c] {
            stack.insert(popup)
        }
        preparePresentation(for: [a, b, c], coordinator: coordinator)

        let mutation = stack.removePopupAndAbove(b.id)
        guard let batch = mutation.dismissalBatch else {
            return XCTFail("Expected dismissal batch")
        }
        var didComplete = false
        let waiter = Task { @MainActor in
            await batch.wait()
            didComplete = true
        }

        coordinator.complete(identity: c.id)
        await Task.yield()
        XCTAssertFalse(didComplete)

        coordinator.complete(identity: b.id)
        await waiter.value

        XCTAssertTrue(didComplete)
        XCTAssertEqual(stack.popups.map(\.id), [a.id])
    }

    func testReduceMotionCompletesWithoutPublishingSnapshots() async {
        let coordinator = PopupDismissalCoordinator()
        let stack = PopupStack(id: .shared, dismissalCoordinator: coordinator)
        let popup = AnyPopup(DismissalPopup())
        stack.insert(popup)
        preparePresentation(for: [popup], coordinator: coordinator)
        coordinator.configure(isRenderingActive: true, reduceMotion: true)

        let mutation = stack.removeLast()

        XCTAssertTrue(coordinator.snapshots.isEmpty)
        await mutation.dismissalBatch?.wait()
    }

    func testMissingPresentationDoesNotCreateUnfinishableBatch() async {
        let coordinator = PopupDismissalCoordinator()
        coordinator.configure(isRenderingActive: true, reduceMotion: false)
        let stack = PopupStack(id: .shared, dismissalCoordinator: coordinator)
        stack.insert(AnyPopup(DismissalPopup()))

        let mutation = stack.removeLast()

        XCTAssertTrue(coordinator.snapshots.isEmpty)
        await mutation.dismissalBatch?.wait()
    }

    func testCancelAllClearsSnapshotsAndResumesWaiters() async {
        let coordinator = PopupDismissalCoordinator()
        let stack = PopupStack(id: .shared, dismissalCoordinator: coordinator)
        let popup = AnyPopup(DismissalPopup())
        stack.insert(popup)
        preparePresentation(for: [popup], coordinator: coordinator)
        let mutation = stack.removeLast()
        guard let batch = mutation.dismissalBatch else {
            return XCTFail("Expected dismissal batch")
        }
        var didComplete = false
        let waiter = Task { @MainActor in
            await batch.wait()
            didComplete = true
        }

        coordinator.cancelAll()
        await waiter.value

        XCTAssertTrue(didComplete)
        XCTAssertTrue(coordinator.snapshots.isEmpty)
    }

    func testDismissalBlocksOutsideInteractionUntilSnapshotCompletes() {
        let coordinator = PopupDismissalCoordinator()
        let stack = PopupStack(id: .shared, dismissalCoordinator: coordinator)
        let popup = AnyPopup(DismissalPopup())
        stack.insert(popup)
        let map = preparePresentation(for: [popup], coordinator: coordinator)

        stack.removeLast()
        map.publish(PopupLayoutPlan(
            items: [],
            backdrops: [],
            shieldPlacements: [],
            interactionRegions: [],
            failures: []
        ))

        XCTAssertEqual(map.action(at: .zero), .consume)

        coordinator.complete(identity: popup.id)

        XCTAssertEqual(map.action(at: .zero), .passThrough(to: nil))
    }
}

@MainActor
@discardableResult
private func preparePresentation(
    for popups: [AnyPopup],
    coordinator: PopupDismissalCoordinator
) -> PopupInteractionMap {
    let environment = PopupEnvironment(
        containerSize: CGSize(width: 600, height: 900),
        safeArea: EdgeInsets(),
        keyboardOcclusionHeight: 0,
        accessibilityReduceMotion: false
    )
    let sizes = Dictionary(
        uniqueKeysWithValues: popups.map { ($0.id, CGSize(width: 200, height: 100)) }
    )
    let map = PopupInteractionMap()
    map.publish(PopupLayoutPlan.resolve(
        popups: popups,
        environment: environment,
        contentSizes: sizes
    ))
    coordinator.bindInteractionMap(map)
    coordinator.configure(isRenderingActive: true, reduceMotion: false)
    return map
}

private struct DismissalPopup: Popup {
    let popupConfig = ContainerPopupConfig.center(
        CenterPopupConfig().size(width: .fixed(200), height: .fixed(100))
    )

    var body: some View {
        Text("Popup")
    }
}
