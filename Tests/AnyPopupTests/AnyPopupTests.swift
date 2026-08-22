import SwiftUI
import XCTest
@testable import AnyPopup

@MainActor
final class AnyPopupTests: XCTestCase {
    func testTypeErasureKeepsIdentityTypeConfigurationAndMetadata() {
        let popup = TestContainerPopup()
            .setCustomID("menu")
            .dismissAfter(2.5)
            .dismissKeyboardOnDismissal(false)

        let erased = AnyPopup(popup)

        XCTAssertEqual(erased.popupTypeName, String(reflecting: TestContainerPopup.self))
        XCTAssertEqual(erased.customID, "menu")
        XCTAssertEqual(erased.dismissAfter, 2.5)
        XCTAssertFalse(erased.dismissKeyboardOnDismissal)
        guard case let .container(config) = erased.configuration else {
            return XCTFail("Expected container configuration")
        }
        XCTAssertEqual(config.defaultPresentation.kind, .center)
    }

    func testEveryPresentationGetsUniqueStableIdentity() {
        let first = AnyPopup(TestContainerPopup())
        let second = AnyPopup(TestContainerPopup())

        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(first.uniquenessKey, second.uniquenessKey)
    }

    func testAnchoredTypeErasureRequiresExplicitAnchorSource() {
        let frame = CGRect(x: 10, y: 20, width: 30, height: 40)
        let erased = AnyPopup(TestAnchoredPopup(), anchorSource: .frame(frame))

        XCTAssertEqual(erased.anchorSource, .frame(frame))
        guard case .anchored = erased.configuration else {
            return XCTFail("Expected anchored configuration")
        }
    }

    func testEnvironmentObjectModifierStaysInCommandMetadata() {
        let command = TestContainerPopup().setEnvironmentObject(TestEnvironmentObject())

        XCTAssertEqual(command.popupCommandMetadata.environmentObjects.count, 1)
    }
}

private struct TestContainerPopup: Popup {
    let popupConfig = ContainerPopupConfig.center()

    var body: some View {
        Text("Container")
    }
}

private struct TestAnchoredPopup: Popup {
    let popupConfig = AnchoredPopupConfig()

    var body: some View {
        Text("Anchored")
    }
}

@MainActor
private final class TestEnvironmentObject: ObservableObject {}
