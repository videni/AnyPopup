import AppKit
import Combine
import SwiftUI
import XCTest
@testable import AnyPopup

@MainActor
final class PopupHostedLifecycleTests: XCTestCase {
    func testInitiallyNonemptyHostPublishesPresented() async throws {
        let probe = HostedMountProbe()
        let harness = HostedPopupHarness(initialPopup: AnyPopup(HostedCenterPopup(probe: probe)))
        defer { harness.close() }
        try await harness.waitUntil { !probe.presentationFrames.isEmpty }
        XCTAssertEqual(probe.presentationFrames.count, 1)
    }

    func testReduceMotionPublishesPresentedAtFullSize() async throws {
        let probe = HostedMountProbe()
        let harness = HostedPopupHarness(reduceMotion: true)
        defer { harness.close() }
        harness.stack.insert(AnyPopup(HostedCenterPopup(probe: probe)))
        try await harness.waitUntil { !probe.presentationFrames.isEmpty }
        XCTAssertEqual(probe.presentationFrames.first?.width, 270)
    }

    func testPresentedSignalArrivesAfterContentReachesFullSizeAtScreenCenter() async throws {
        let probe = HostedMountProbe()
        let harness = HostedPopupHarness()
        defer { harness.close() }
        harness.stack.insert(AnyPopup(HostedCenterPopup(probe: probe)))

        try await harness.waitUntil { !probe.presentationFrames.isEmpty }

        let frame = try XCTUnwrap(probe.presentationFrames.first)
        XCTAssertEqual(frame.width, 270, accuracy: 1)
        XCTAssertEqual(frame.height, 140, accuracy: 1)
        XCTAssertEqual(frame.midX, 300, accuracy: 1)
        XCTAssertEqual(frame.midY, 400, accuracy: 1)
        XCTAssertEqual(probe.presentationFrames.count, 1)
    }

    func testAnimatedKeyboardEnvironmentMovesPresentedContentThroughIntermediatePositions() async throws {
        let probe = HostedMountProbe()
        let harness = HostedPopupHarness()
        defer { harness.close() }
        harness.stack.insert(AnyPopup(HostedCenterPopup(probe: probe)))
        try await harness.waitUntil { !probe.presentationFrames.isEmpty }
        probe.frames.removeAll()

        withAnimation(.easeInOut(duration: 0.25)) {
            harness.updateKeyboardOcclusion(400)
        }
        try await harness.waitUntil { abs((probe.frames.last?.midY ?? 0) - 200) < 1 }

        XCTAssertTrue(probe.frames.contains { $0.midY > 210 && $0.midY < 390 },
                      "Keyboard movement must interpolate, not jump directly to the target")
        XCTAssertEqual(probe.presentationFrames.count, 1)
    }

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
        XCTAssertTrue(probe.presentationFrames.isEmpty, "Cancelling insertion must not later mark content presented")
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
    let controller: NSHostingController<HostedPopupRoot>
    let geometry = HostedPopupGeometry()

    init(initialPopup: AnyPopup? = nil, reduceMotion: Bool = false) {
        let size = CGSize(width: 600, height: 800)
        if let initialPopup {
            stack.insert(initialPopup)
        }
        controller = NSHostingController(rootView: HostedPopupRoot(
            stack: stack, map: map, geometry: geometry, reduceMotion: reduceMotion
        ))
        window = NSWindow(contentRect: CGRect(origin: .zero, size: size),
                          styleMask: [], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentViewController = controller
        window.orderFront(nil)
        controller.view.layoutSubtreeIfNeeded()
    }

    func updateKeyboardOcclusion(_ height: CGFloat) {
        geometry.keyboardHeight = height
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
    var presentationFrames: [CGRect] = []
}

private struct HostedCenterPopup: Popup {
    @Environment(\.isPopupPresented) private var isPresented
    let probe: HostedMountProbe
    let popupConfig = ContainerPopupConfig.center(CenterPopupConfig().background(.none))

    var body: some View {
        TextField("Rename", text: .constant("Document"))
            .frame(width: 270, height: 140)
            .onAppear { probe.appearances += 1 }
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: {
                probe.frames.append($0)
            }
            .onChange(of: isPresented, initial: true) { _, presented in
                if presented, let frame = probe.frames.last {
                    probe.presentationFrames.append(frame)
                }
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

@MainActor
private final class HostedPopupGeometry: ObservableObject {
    @Published var keyboardHeight: CGFloat = 0
}

private struct HostedPopupRoot: View {
    let stack: PopupStack
    let map: PopupInteractionMap
    @ObservedObject var geometry: HostedPopupGeometry
    let reduceMotion: Bool

    var body: some View {
        PopupView(
            popupStack: stack,
            sceneSessionID: "hosted",
            environment: PopupEnvironment(
                containerSize: CGSize(width: 600, height: 800), safeArea: EdgeInsets(),
                keyboardOcclusionHeight: geometry.keyboardHeight, accessibilityReduceMotion: reduceMotion
            ),
            interactionMap: map
        )
    }
}
