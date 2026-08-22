import SwiftUI

public struct TopPopupConfig: PopupConfiguration,
    PopupSizingConfigurable,
    PopupVisualConfigurable,
    PopupTransitionConfigurable,
    PopupOutsideInteractionConfigurable,
    PopupDetentConfigurable {
    public var size: PopupSizePolicy
    public var corners: PopupCorners
    public var background: PopupBackground
    public var backdrop: BackdropPolicy
    public var insertionTransition: PopupTransition
    public var removalTransition: PopupTransition
    public var outsideInteraction: OutsideInteractionPolicy
    public var safeArea: PopupSafeAreaPolicy
    public var drag: DragPolicy
    public var detents: [PopupDetent]
    public var stackAppearance: StackAppearance

    public init() {
        size = .content
        corners = .all(radius: 40)
        background = .color(.white)
        backdrop = .color(.black, opacity: 0.5)
        insertionTransition = .move(from: .top)
        removalTransition = .move(to: .top)
        outsideInteraction = .consume
        safeArea = .contained
        drag = DragPolicy(direction: .up)
        detents = [.large, .fullscreen]
        stackAppearance = .stacked
    }
}
