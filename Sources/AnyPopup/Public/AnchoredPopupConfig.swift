import SwiftUI

public struct AnchoredPopupConfig: PopupConfiguration,
    PopupSizingConfigurable,
    PopupVisualConfigurable,
    PopupTransitionConfigurable,
    PopupOutsideInteractionConfigurable {
    public var size: PopupSizePolicy
    public var corners: PopupCorners
    public var background: PopupBackground
    public var backdrop: BackdropPolicy
    public var insertionTransition: PopupTransition
    public var removalTransition: PopupTransition
    public var outsideInteraction: OutsideInteractionPolicy
    public var sourceAnchor: PopupAnchorPoint
    public var popupAnchor: PopupAnchorPoint
    public var offset: CGSize
    public var screenAvoidance: ScreenAvoidancePolicy

    public init() {
        size = .content
        corners = .all(radius: 13)
        background = .color(.white)
        backdrop = .none
        insertionTransition = .opacity
        removalTransition = .opacity
        outsideInteraction = .dismissTop
        sourceAnchor = .bottom
        popupAnchor = .top
        offset = .zero
        screenAvoidance = .init(edges: .horizontal, padding: 16)
    }

    public func anchor(source: PopupAnchorPoint, popup: PopupAnchorPoint) -> Self {
        var copy = self
        copy.sourceAnchor = source
        copy.popupAnchor = popup
        return copy
    }

    public func offset(x: CGFloat, y: CGFloat) -> Self {
        var copy = self
        copy.offset = CGSize(width: x, height: y)
        return copy
    }

    public func screenAvoidance(edges: Edge.Set, padding: CGFloat) -> Self {
        var copy = self
        copy.screenAvoidance = .init(edges: edges, padding: padding)
        return copy
    }
}
