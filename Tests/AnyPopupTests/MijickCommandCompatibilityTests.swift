import SwiftUI
import XCTest
@testable import AnyPopup

@MainActor
final class MijickCommandCompatibilityTests: XCTestCase {
    func testMijickStyleCommandChainsCompileAndMutateRegisteredStack() async {
        let stackID = PopupStackID("compatibility-\(UUID().uuidString)")
        let sceneID = "scene-\(UUID().uuidString)"
        let stack = PopupStack(id: stackID)
        let model = CompatibilityModel()
        PopupStackRegistry.shared.register(stack, sceneSessionID: sceneID)
        defer {
            PopupStackRegistry.shared.unregister(
                sceneSessionID: sceneID,
                popupStackID: stackID
            )
        }

        await CompatibilityContainerPopup()
            .setCustomID("browser")
            .setEnvironmentObject(model)
            .dismissAfter(5)
            .present(popupStackID: stackID)
        await CompatibilityAnchoredPopup()
            .setEnvironmentObject(model)
            .present(
                anchoredTo: "menu",
                customID: "menu",
                popupStackID: stackID
            )

        XCTAssertEqual(stack.popups.compactMap(\.customID), ["browser", "menu"])

        await dismissAllPopups(excluding: ["browser"], popupStackID: stackID)

        XCTAssertEqual(stack.popups.compactMap(\.customID), ["browser"])

        await dismissPopup(CompatibilityContainerPopup.self, popupStackID: stackID)

        XCTAssertTrue(stack.popups.isEmpty)
    }
}

private struct CompatibilityContainerPopup: Popup {
    let popupConfig = ContainerPopupConfig.center()

    var body: some View {
        Text("Container")
    }
}

private struct CompatibilityAnchoredPopup: Popup {
    let popupConfig = AnchoredPopupConfig()

    var body: some View {
        Text("Anchored")
    }
}

@MainActor
private final class CompatibilityModel: ObservableObject {}
