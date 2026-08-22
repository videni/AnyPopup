import XCTest
@testable import AnyPopup

final class StackAppearanceTests: XCTestCase {
    func testFlatAppearanceLeavesEveryPopupUntransformed() {
        let appearances = StackAppearance.flat.resolve(
            popupCount: 3,
            edge: .bottom,
            activeDismissalProgress: 0
        )

        XCTAssertEqual(appearances.map(\.transform), [.identity, .identity, .identity])
        XCTAssertEqual(appearances.map(\.opacity), [1, 1, 1])
        XCTAssertEqual(appearances.map(\.overlayOpacity), [0, 0, 0])
    }

    func testBottomStackedAppearanceShowsOnlyTopThreeItems() {
        let appearances = StackAppearance.stacked.resolve(
            popupCount: 4,
            edge: .bottom,
            activeDismissalProgress: 0
        )

        XCTAssertEqual(appearances[3].transform, .identity)
        XCTAssertEqual(
            appearances[2].transform,
            PopupTransform(translation: CGSize(width: 0, height: -8), scale: 0.975)
        )
        XCTAssertEqual(
            appearances[1].transform,
            PopupTransform(translation: CGSize(width: 0, height: -16), scale: 0.95)
        )
        XCTAssertEqual(appearances[0].opacity, 0)
        XCTAssertEqual(appearances[2].overlayOpacity, 0.2)
        XCTAssertEqual(appearances[1].overlayOpacity, 0.4)
    }

    func testTopStackOffsetsPointDownward() {
        let appearances = StackAppearance.stacked.resolve(
            popupCount: 2,
            edge: .top,
            activeDismissalProgress: 0
        )

        XCTAssertEqual(appearances[0].transform.translation.height, 8)
    }

    func testDismissalProgressRevealsImmediateLowerPopup() {
        let appearances = StackAppearance.stacked.resolve(
            popupCount: 3,
            edge: .bottom,
            activeDismissalProgress: 1
        )

        XCTAssertEqual(appearances[1].transform.scale, 1)
        XCTAssertEqual(appearances[1].overlayOpacity, 0)
        XCTAssertEqual(appearances[0].transform.scale, 0.965, accuracy: 0.000_001)
        XCTAssertEqual(appearances[0].overlayOpacity, 0.24, accuracy: 0.000_001)
    }

    func testProgressIsClampedToUnitInterval() {
        XCTAssertEqual(
            StackAppearance.stacked.resolve(
                popupCount: 2,
                edge: .bottom,
                activeDismissalProgress: 2
            ),
            StackAppearance.stacked.resolve(
                popupCount: 2,
                edge: .bottom,
                activeDismissalProgress: 1
            )
        )
    }
}
