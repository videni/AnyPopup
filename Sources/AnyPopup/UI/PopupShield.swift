import SwiftUI

public struct PopupShieldPlacement: Sendable, Equatable {
    public let topPopupIndex: Int
}

public enum ShieldPlan {
    public static func resolve(popupCount: Int) -> [PopupShieldPlacement] {
        guard popupCount > 0 else { return [] }
        return [PopupShieldPlacement(topPopupIndex: popupCount - 1)]
    }
}

struct PopupShield: View {
    let onTap: (CGPoint) -> Void

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture().onEnded { value in
                    onTap(value.location)
                }
            )
    }
}
