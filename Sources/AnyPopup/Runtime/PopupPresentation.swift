import SwiftUI

public struct PopupTransform: Sendable, Equatable {
    public let translation: CGSize
    public let scale: CGFloat

    public static let identity = Self(translation: .zero, scale: 1)

    public init(translation: CGSize, scale: CGFloat) {
        self.translation = translation
        self.scale = scale
    }
}

public struct PopupPresentation: Sendable, Equatable {
    public let frame: CGRect
    public let transform: PopupTransform
    public let opacity: Double
    public let zIndex: Double
    public let attachedEdges: Edge.Set
    public let corners: PopupCorners
    public let background: PopupBackground
    public let backdrop: BackdropPolicy
    public let insertionTransition: PopupTransition
    public let removalTransition: PopupTransition
    public let layoutTransition: PopupTransition
    public let drag: DragPolicy
    public let outsideInteraction: OutsideInteractionPolicy
    public let stackAppearance: StackAppearance
    public let anchoredGeometry: AnchoredPopupGeometry?
}
