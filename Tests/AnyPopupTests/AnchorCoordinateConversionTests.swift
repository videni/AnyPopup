import XCTest
@testable import AnyPopup

final class AnchorCoordinateConversionTests: XCTestCase {
    func testStaticPopupViewFrameUsesIdentityConversion() throws {
        let frame = CGRect(x: 10, y: 20, width: 30, height: 40)

        let converted = try AnchorCoordinateConverter.convert(
            frame,
            from: .popupView,
            to: .popupView
        )

        XCTAssertEqual(converted, frame)
    }

    func testUIKitWindowFrameConvertsThroughSceneCoordinates() throws {
        let frameInSourceWindow = CGRect(x: 10, y: 15, width: 30, height: 40)
        let sourceWindow = PopupCoordinateSpace(
            transformToScene: CGAffineTransform(translationX: 100, y: 200)
        )
        let popupWindow = PopupCoordinateSpace(
            transformToScene: CGAffineTransform(translationX: 20, y: 50)
        )

        let converted = try AnchorCoordinateConverter.convert(
            frameInSourceWindow,
            from: sourceWindow,
            to: popupWindow
        )

        XCTAssertEqual(converted, CGRect(x: 90, y: 165, width: 30, height: 40))
    }

    func testSwiftUISourceScaleAndTranslationConvertToPopupView() throws {
        let sourceSpace = PopupCoordinateSpace(
            transformToScene: CGAffineTransform(scaleX: 2, y: 2)
                .translatedBy(x: 10, y: 20)
        )

        let converted = try AnchorCoordinateConverter.convert(
            CGRect(x: 5, y: 10, width: 20, height: 30),
            from: sourceSpace,
            to: .popupView
        )

        XCTAssertEqual(converted, CGRect(x: 30, y: 60, width: 40, height: 60))
    }

    func testNonInvertiblePopupSpaceFailsExplicitly() {
        let nonInvertible = PopupCoordinateSpace(
            transformToScene: CGAffineTransform(scaleX: 0, y: 1)
        )

        XCTAssertThrowsError(
            try AnchorCoordinateConverter.convert(
                CGRect(x: 10, y: 10, width: 20, height: 20),
                from: .popupView,
                to: nonInvertible
            )
        ) { error in
            XCTAssertEqual(error as? AnchorCoordinateConversionError, .nonInvertibleDestination)
        }
    }

    func testInvalidSourceFrameFailsExplicitly() {
        XCTAssertThrowsError(
            try AnchorCoordinateConverter.convert(.zero, from: .popupView, to: .popupView)
        ) { error in
            XCTAssertEqual(error as? AnchorCoordinateConversionError, .invalidSourceFrame)
        }
    }

    @MainActor
    func testRegistryStoresConvertedPopupViewFrame() {
        let registry = AnchorRegistry()
        let key = AnchorRegistry.Key(
            sceneSessionID: "S1",
            popupStackID: .shared,
            anchorID: "menu"
        )

        let accepted = registry.setFrame(
            CGRect(x: 10, y: 15, width: 30, height: 40),
            from: PopupCoordinateSpace(
                transformToScene: CGAffineTransform(translationX: 100, y: 200)
            ),
            to: PopupCoordinateSpace(
                transformToScene: CGAffineTransform(translationX: 20, y: 50)
            ),
            for: key
        )

        XCTAssertTrue(accepted)
        XCTAssertEqual(
            registry.frame(for: key),
            CGRect(x: 90, y: 165, width: 30, height: 40)
        )
    }
}
