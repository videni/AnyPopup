import SwiftUI
import XCTest
@testable import AnyPopup

final class BackdropCompositionTests: XCTestCase {
    func testClearTopBackdropDoesNotReplaceLowerBackdrop() {
        let layers = BackdropComposition.resolve([
            .color(.black, opacity: 0.5),
            .none
        ])

        XCTAssertEqual(layers.count, 1)
        XCTAssertEqual(layers[0].popupIndex, 0)
        XCTAssertEqual(layers[0].policy, .color(.black, opacity: 0.5))
    }

    func testBackdropLayersPreservePopupOrder() {
        let layers = BackdropComposition.resolve([
            .color(.black, opacity: 0.2),
            .color(.blue, opacity: 0.4)
        ])

        XCTAssertEqual(layers.map(\.popupIndex), [0, 1])
        XCTAssertEqual(layers.map(\.policy), [
            .color(.black, opacity: 0.2),
            .color(.blue, opacity: 0.4)
        ])
    }

    func testOneStackProducesAtMostOneShield() {
        XCTAssertTrue(ShieldPlan.resolve(popupCount: 0).isEmpty)
        XCTAssertEqual(ShieldPlan.resolve(popupCount: 1).count, 1)
        XCTAssertEqual(ShieldPlan.resolve(popupCount: 2).count, 1)
        XCTAssertEqual(
            ShieldPlan.resolve(popupCount: 2).first?.topPopupIndex,
            1
        )
    }
}
