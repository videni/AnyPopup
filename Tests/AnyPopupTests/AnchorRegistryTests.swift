import XCTest
@testable import AnyPopup

@MainActor
final class AnchorRegistryTests: XCTestCase {
    @MainActor
    func testCompatibilityFrameLookupUsesActiveSceneAndStack() {
        let sceneA = "anchor-compatibility-a"
        let sceneB = "anchor-compatibility-b"
        let stackID = PopupStackID("anchor-compatibility")
        let stackA = PopupStack(id: stackID)
        let stackB = PopupStack(id: stackID)
        PopupStackRegistry.shared.register(stackA, sceneSessionID: sceneA)
        PopupStackRegistry.shared.register(stackB, sceneSessionID: sceneB)
        defer {
            PopupStackRegistry.shared.setActiveSceneSessionID(nil)
            PopupStackRegistry.shared.unregister(sceneSessionID: sceneA, popupStackID: stackID)
            PopupStackRegistry.shared.unregister(sceneSessionID: sceneB, popupStackID: stackID)
            AnchorRegistry.shared.removeAll(sceneSessionID: sceneA)
            AnchorRegistry.shared.removeAll(sceneSessionID: sceneB)
        }

        _ = AnchorRegistry.shared.setFrame(
            CGRect(x: 10, y: 20, width: 30, height: 40),
            for: .init(sceneSessionID: sceneA, popupStackID: stackID, anchorID: "tool")
        )
        _ = AnchorRegistry.shared.setFrame(
            CGRect(x: 50, y: 60, width: 70, height: 80),
            for: .init(sceneSessionID: sceneB, popupStackID: stackID, anchorID: "tool")
        )

        PopupStackRegistry.shared.setActiveSceneSessionID(sceneB)

        XCTAssertEqual(
            AnchorRegistry.frame(forKey: "tool", popupStackID: stackID),
            CGRect(x: 50, y: 60, width: 70, height: 80)
        )
    }

    private var registry = AnchorRegistry()

    func testSameAnchorIDInDifferentScenesDoesNotCollide() {
        let key1 = AnchorRegistry.Key(
            sceneSessionID: "S1",
            popupStackID: .shared,
            anchorID: "menu"
        )
        let key2 = AnchorRegistry.Key(
            sceneSessionID: "S2",
            popupStackID: .shared,
            anchorID: "menu"
        )
        let frame1 = CGRect(x: 10, y: 10, width: 20, height: 20)
        let frame2 = CGRect(x: 50, y: 50, width: 20, height: 20)

        XCTAssertTrue(registry.setFrame(frame1, for: key1))
        XCTAssertTrue(registry.setFrame(frame2, for: key2))

        XCTAssertEqual(registry.frame(for: key1), frame1)
        XCTAssertEqual(registry.frame(for: key2), frame2)
    }

    func testMovingAnchorReplacesFrameForSameKey() {
        let key = AnchorRegistry.Key(
            sceneSessionID: "S1",
            popupStackID: .shared,
            anchorID: "menu"
        )
        registry.setFrame(CGRect(x: 10, y: 10, width: 20, height: 20), for: key)

        registry.setFrame(CGRect(x: 80, y: 90, width: 20, height: 20), for: key)

        XCTAssertEqual(
            registry.frame(for: key),
            CGRect(x: 80, y: 90, width: 20, height: 20)
        )
    }

    func testRemoveFrameAndSceneCleanupAreScoped() {
        let menu = AnchorRegistry.Key(
            sceneSessionID: "S1",
            popupStackID: .shared,
            anchorID: "menu"
        )
        let toolbar = AnchorRegistry.Key(
            sceneSessionID: "S1",
            popupStackID: .shared,
            anchorID: "toolbar"
        )
        let otherScene = AnchorRegistry.Key(
            sceneSessionID: "S2",
            popupStackID: .shared,
            anchorID: "menu"
        )
        for key in [menu, toolbar, otherScene] {
            registry.setFrame(CGRect(x: 10, y: 10, width: 20, height: 20), for: key)
        }

        registry.removeFrame(for: toolbar)
        registry.removeAll(sceneSessionID: "S1")

        XCTAssertNil(registry.frame(for: menu))
        XCTAssertNil(registry.frame(for: toolbar))
        XCTAssertNotNil(registry.frame(for: otherScene))
    }

    func testInvalidFrameRemovesStaleValueAndReportsFailure() {
        let key = AnchorRegistry.Key(
            sceneSessionID: "S1",
            popupStackID: .shared,
            anchorID: "menu"
        )
        registry.setFrame(CGRect(x: 10, y: 10, width: 20, height: 20), for: key)

        let accepted = registry.setFrame(.zero, for: key)

        XCTAssertFalse(accepted)
        XCTAssertNil(registry.frame(for: key))
        XCTAssertEqual(registry.lastError, .invalidFrame(key))
    }
}
