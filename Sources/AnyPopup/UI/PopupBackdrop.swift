import SwiftUI

public struct PopupBackdropLayer: Sendable, Equatable {
    public let popupIndex: Int
    public let policy: BackdropPolicy
}

public enum BackdropComposition {
    public static func resolve(_ policies: [BackdropPolicy]) -> [PopupBackdropLayer] {
        policies.enumerated().compactMap { index, policy in
            guard policy != .none else { return nil }
            return PopupBackdropLayer(popupIndex: index, policy: policy)
        }
    }
}

struct PopupBackdrop: View {
    let policy: BackdropPolicy

    @ViewBuilder
    var body: some View {
        switch policy {
        case .none:
            Color.clear
        case let .color(color, opacity):
            color.opacity(opacity)
        }
    }
}
