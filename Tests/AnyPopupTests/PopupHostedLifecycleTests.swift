import AppKit
import Combine
import SwiftUI
import XCTest
@testable import AnyPopup

@MainActor
final class PopupHostedLifecycleTests: XCTestCase {
    func testDismissalPreservesMountedContentAndCompletesWithoutManualSignal() async throws {
        let probe = HostedMountProbe()
        let popup = AnyPopup(HostedCenterPopup(probe: probe))
        let harness = HostedPopupHarness()
        defer { harness.close() }
        harness.stack.insert(popup)
        try await harness.waitUntil { probe.appearances > 0 }
        let frame = try XCTUnwrap(harness.map.snapshot().presentations.first?.presentation.frame)
        XCTAssertGreaterThan(frame.width, 0)
        XCTAssertGreaterThan(frame.height, 0)

        let mutation = harness.stack.removeLast()
        XCTAssertNotNil(mutation.dismissalBatch)
        var returned = false
        let waiter = Task { @MainActor in
            await mutation.dismissalBatch?.wait()
            returned = true
        }
        try await harness.waitUntil { returned }
        waiter.cancel()

        XCTAssertEqual(probe.appearances, 1, "Dismissing must not mount fresh content or rerun focus-on-appear")
        XCTAssertFalse(harness.map.snapshot().isDismissalBlocking)
    }

    func testDismissalDoesNotTemporarilyReportEmptyScene() async throws {
        let harness = HostedPopupHarness()
        defer { harness.close() }
        let popup = AnyPopup(HostedCenterPopup(probe: HostedMountProbe()))
        harness.stack.insert(popup)
        try await harness.waitUntil { !harness.map.snapshot().presentations.isEmpty }
        var hasVisualContent: [Bool] = []
        let observation = Publishers.CombineLatest(
            harness.stack.$popups,
            harness.stack.dismissalCoordinator.$snapshots
        ).sink { popups, snapshots in
            hasVisualContent.append(!popups.isEmpty || !snapshots.isEmpty)
        }

        harness.stack.removeLast()

        XCTAssertFalse(hasVisualContent.contains(false), "Scene must keep its key window during active-to-dismissal handoff")
        withExtendedLifetime(observation) {}
    }

    func testAnchoredMenuMeasuresAndNaturallyCompletesDismissal() async throws {
        let harness = HostedPopupHarness()
        defer { harness.close() }
        let popup = AnyPopup(
            HostedMenuPopup(),
            anchorSource: .frame(CGRect(x: 100, y: 100, width: 28, height: 28))
        )
        harness.stack.insert(popup)
        try await harness.waitUntil { !harness.map.snapshot().presentations.isEmpty }
        let frame = try XCTUnwrap(harness.map.snapshot().presentations.first?.presentation.frame)
        XCTAssertEqual(frame.width, 152, accuracy: 1)
        XCTAssertEqual(frame.height, 96, accuracy: 1)
        XCTAssertEqual(harness.map.action(at: .zero), .dismissTop)

        let mutation = harness.stack.removeLast()
        XCTAssertNotNil(mutation.dismissalBatch)
        try await harness.waitUntil { harness.stack.dismissalCoordinator.snapshots.isEmpty }
        XCTAssertFalse(harness.map.snapshot().isDismissalBlocking)
    }

    func testKeyboardEnvironmentChangeKeepsDepartingContentCenteredAtFrozenFrame() async throws {
        let probe = HostedMountProbe()
        let harness = HostedPopupHarness()
        defer { harness.close() }
        harness.stack.insert(AnyPopup(HostedCenterPopup(probe: probe)))
        try await harness.waitUntil { !probe.frames.isEmpty }
        let initial = try XCTUnwrap(probe.frames.last)
        harness.stack.removeLast()
        try await harness.waitUntil {
            harness.stack.dismissalCoordinator.snapshots.first?.isDeparting == true
        }
        probe.frames.removeAll()

        harness.updateKeyboardOcclusion(400)
        try await harness.waitUntil { harness.stack.dismissalCoordinator.snapshots.isEmpty }

        XCTAssertFalse(probe.frames.isEmpty)
        for frame in probe.frames {
            XCTAssertEqual(frame.midX, initial.midX, accuracy: 1)
            XCTAssertEqual(frame.midY, initial.midY, accuracy: 1)
        }
    }
}

@MainActor
private final class HostedPopupHarness {
    let stack = PopupStack(id: PopupStackID("hosted-\(UUID())"))
    let map = PopupInteractionMap()
    let window: NSWindow
    let controller: NSHostingController<PopupView>

    init() {
        let size = CGSize(width: 600, height: 800)
        controller = NSHostingController(rootView: PopupView(
            popupStack: stack,
            sceneSessionID: "hosted",
            environment: PopupEnvironment(
                containerSize: size, safeArea: EdgeInsets(),
                keyboardOcclusionHeight: 0, accessibilityReduceMotion: false
            ),
            interactionMap: map
        ))
        window = NSWindow(contentRect: CGRect(origin: .zero, size: size),
                          styleMask: [], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentViewController = controller
        window.orderFront(nil)
        controller.view.layoutSubtreeIfNeeded()
    }

    func updateKeyboardOcclusion(_ height: CGFloat) {
        controller.rootView = PopupView(
            popupStack: stack,
            sceneSessionID: "hosted",
            environment: PopupEnvironment(
                containerSize: CGSize(width: 600, height: 800), safeArea: EdgeInsets(),
                keyboardOcclusionHeight: height, accessibilityReduceMotion: false
            ),
            interactionMap: map
        )
    }

    func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(3)
        while !condition(), Date() < deadline {
            window.contentView?.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertTrue(condition(), "Hosted SwiftUI lifecycle did not complete within 3 seconds")
    }

    func close() {
        window.orderOut(nil)
        window.contentViewController = nil
        window.close()
    }
}

@MainActor
private final class HostedMountProbe {
    var appearances = 0
    var frames: [CGRect] = []
}

private struct HostedCenterPopup: Popup {
    let probe: HostedMountProbe
    let popupConfig = ContainerPopupConfig.center(CenterPopupConfig().background(.none))

    var body: some View {
        TextField("Rename", text: .constant("Document"))
            .frame(width: 270, height: 140)
            .onAppear { probe.appearances += 1 }
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: {
                probe.frames.append($0)
            }
    }
}

private struct HostedMenuPopup: Popup {
    let popupConfig = AnchoredPopupConfig().background(.none)

    var body: some View {
        VStack(spacing: 0) {
            Button("Rename") {}
                .frame(height: 44)
            Button("Delete") {}
                .frame(height: 44)
        }
        .frame(width: 120)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}
