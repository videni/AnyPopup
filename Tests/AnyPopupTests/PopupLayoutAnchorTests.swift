import SwiftUI
import AppKit
import XCTest
@testable import AnyPopup

@MainActor
final class PopupLayoutAnchorTests: XCTestCase {
    func testFirstRenderResolvesSourceInOffsetContainerCoordinates() throws {
        let map = PopupInteractionMap()
        let stack = PopupStack(id: PopupStackID("local"))
        stack.insert(AnyPopup(AnchorTestPopup(), anchorSource: .tracked("button")))
        let source = ZStack(alignment: .topLeading) {
            Color.clear.frame(width: 36, height: 36)
                .popupAnchor("button", popupStackID: stack.id)
                .offset(x: 300, y: 20)
        }.frame(width: 500, height: 600, alignment: .topLeading)
        let host = PopupLayoutContainer(content: source, popupStack: stack,
            defaults: PopupDefaults(), interactionMap: map)
            .padding(.leading, 70).padding(.top, 60)
        render(host)
        XCTAssertEqual(try XCTUnwrap(map.snapshot().regions.first).frame,
            CGRect(x: 258, y: 56, width: 120, height: 80))
    }

    func testDuplicateAnchorNamesStayWithinTheirStack() throws {
        let map = PopupInteractionMap()
        let stack = PopupStack(id: PopupStackID("target"))
        stack.insert(AnyPopup(AnchorTestPopup(), anchorSource: .tracked("button")))
        let source = ZStack(alignment: .topLeading) {
            Color.clear.frame(width: 36, height: 36)
                .popupAnchor("button", popupStackID: stack.id).offset(x: 300, y: 20)
            Color.clear.frame(width: 36, height: 36)
                .popupAnchor("button", popupStackID: PopupStackID("other")).offset(x: 50, y: 250)
        }.frame(width: 500, height: 600, alignment: .topLeading)
        render(PopupLayoutContainer(content: source, popupStack: stack,
            defaults: PopupDefaults(), interactionMap: map))
        XCTAssertEqual(try XCTUnwrap(map.snapshot().regions.first).frame.minY, 56)
    }

    func testMissingAndZeroSizeSourceNeverPublishesInteractionRegion() {
        for present in [false, true] {
            let map = PopupInteractionMap()
            let stack = PopupStack(id: PopupStackID("missing"))
            stack.insert(AnyPopup(AnchorTestPopup(), anchorSource: .tracked("button")))
            let source = ZStack {
                if present { Color.clear.frame(width: 0, height: 0).popupAnchor("button", popupStackID: stack.id) }
            }.frame(width: 500, height: 600)
            render(PopupLayoutContainer(content: source, popupStack: stack,
                defaults: PopupDefaults(), interactionMap: map))
            XCTAssertTrue(map.snapshot().regions.isEmpty)
            XCTAssertNil(map.snapshot().topPolicy)
        }
    }

    func testCompoundAnchorUsesCurrentButtonXAndToolbarY() throws {
        let map = PopupInteractionMap()
        let stack = PopupStack(id: PopupStackID("compound"))
        stack.insert(AnyPopup(AnchorTestPopup(), anchorSource: .aligned(horizontal: "button", vertical: "toolbar")))
        let source = ZStack(alignment: .topLeading) {
            Color.clear.frame(width: 500, height: 100).popupAnchor("toolbar", popupStackID: stack.id)
            Color.clear.frame(width: 36, height: 36).popupAnchor("button", popupStackID: stack.id).offset(x: 300, y: 20)
        }.frame(width: 500, height: 600, alignment: .topLeading)
        render(PopupLayoutContainer(content: source, popupStack: stack,
            defaults: PopupDefaults(), interactionMap: map))
        XCTAssertEqual(try XCTUnwrap(map.snapshot().regions.first).frame,
            CGRect(x: 258, y: 100, width: 120, height: 80))
    }

    func testMountedSourceMovesDisappearsAndDoesNotReopenAfterCancellation() throws {
        let model = HostedAnchorModel()
        let stack = PopupStack(id: PopupStackID("lifecycle"))
        let map = PopupInteractionMap()
        stack.insert(AnyPopup(AnchorTestPopup(), anchorSource: .tracked("button")))
        let host = NSHostingController(rootView: HostedAnchorFixture(model: model, stack: stack, map: map))
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 500, height: 600),
            styleMask: [], backing: .buffered, defer: false)
        window.contentViewController = host
        window.orderFront(nil)
        defer { window.orderOut(nil); window.contentViewController = nil }
        func layout() {
            for _ in 0..<3 {
                host.view.layoutSubtreeIfNeeded()
                RunLoop.main.run(until: Date().addingTimeInterval(0.02))
            }
        }
        layout()
        XCTAssertEqual(try XCTUnwrap(map.snapshot().regions.first).frame.origin, CGPoint(x: 258, y: 56))
        model.offset = CGPoint(x: 350, y: 60)
        layout()
        XCTAssertEqual(try XCTUnwrap(map.snapshot().regions.first).frame.origin, CGPoint(x: 308, y: 96))
        model.isVisible = false
        layout()
        XCTAssertTrue(map.snapshot().regions.isEmpty)
        XCTAssertNil(map.snapshot().topPolicy)
        stack.removeAll()
        model.isVisible = true
        layout()
        XCTAssertTrue(map.snapshot().regions.isEmpty)
    }

    func testNestedPopupUsesItsOwnSourceTreeAndLocalStack() throws {
        let outer = PopupStack(id: PopupStackID("outer"))
        let inner = PopupStack(id: PopupStackID("inner"))
        let outerMap = PopupInteractionMap()
        let innerMap = PopupInteractionMap()
        inner.insert(AnyPopup(AnchorTestPopup(), anchorSource: .tracked("button")))
        outer.insert(AnyPopup(NestedAnchorPopup(stack: inner, map: innerMap), anchorSource: .tracked("button")))
        let source = ZStack(alignment: .topLeading) {
            Color.clear.frame(width: 36, height: 36).popupAnchor("button", popupStackID: outer.id)
                .offset(x: 300, y: 20)
        }.frame(width: 500, height: 600, alignment: .topLeading)
        render(PopupLayoutContainer(content: source, popupStack: outer, defaults: PopupDefaults(), interactionMap: outerMap))
        XCTAssertEqual(try XCTUnwrap(innerMap.snapshot().regions.first).frame.origin, CGPoint(x: 108, y: 46))
        XCTAssertEqual(outerMap.snapshot().regions.count, 1)
    }

    private func render<V: View>(_ view: V) {
        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(width: 600, height: 900)
        XCTAssertNotNil(renderer.cgImage)
    }
}

private struct AnchorTestPopup: Popup {
    let popupConfig = AnchoredPopupConfig()
    var body: some View { Color.red.frame(width: 120, height: 80) }
}

@MainActor
private final class HostedAnchorModel: ObservableObject {
    @Published var offset = CGPoint(x: 300, y: 20)
    @Published var isVisible = true
}

private struct HostedAnchorFixture: View {
    @ObservedObject var model: HostedAnchorModel
    let stack: PopupStack
    let map: PopupInteractionMap
    var body: some View {
        let source = ZStack(alignment: .topLeading) {
            if model.isVisible {
                Color.clear.frame(width: 36, height: 36).popupAnchor("button", popupStackID: stack.id)
                    .offset(x: model.offset.x, y: model.offset.y)
            }
        }.frame(width: 500, height: 600, alignment: .topLeading)
        PopupLayoutContainer(content: source, popupStack: stack, defaults: PopupDefaults(), interactionMap: map)
    }
}

private struct NestedAnchorPopup: Popup {
    let stack: PopupStack
    let map: PopupInteractionMap
    let popupConfig = AnchoredPopupConfig()
    var body: some View {
        let source = ZStack(alignment: .topLeading) {
            Color.clear.frame(width: 36, height: 36).popupAnchor("button", popupStackID: stack.id).offset(x: 150, y: 10)
        }.frame(width: 300, height: 250, alignment: .topLeading)
        PopupLayoutContainer(content: source, popupStack: stack, defaults: PopupDefaults(), interactionMap: map)
    }
}
