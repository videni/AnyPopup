import SwiftUI

public struct BottomPopupConfig: PopupConfiguration,
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
    public var keyboardAvoidance: PopupKeyboardAvoidance

    public init() {
        size = .content
        corners = .all(radius: 40)
        background = .color(.white)
        backdrop = .color(.black, opacity: 0.5)
        insertionTransition = .move(from: .bottom)
        removalTransition = .move(to: .bottom)
        outsideInteraction = .consume
        safeArea = .contained
        drag = DragPolicy(direction: .down)
        detents = [.large, .fullscreen]
        stackAppearance = .stacked
        keyboardAvoidance = .respectVisibleBottom
    }
}
