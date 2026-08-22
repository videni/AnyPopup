import SwiftUI

public struct CenterPopupConfig: PopupConfiguration,
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
    public var keyboardAvoidance: PopupKeyboardAvoidance
    public var stackAppearance: StackAppearance

    public init() {
        size = .content
        corners = .all(radius: 24)
        background = .color(.white)
        backdrop = .color(.black, opacity: 0.5)
        insertionTransition = .scaleAndOpacity
        removalTransition = .scaleAndOpacity
        outsideInteraction = .consume
        keyboardAvoidance = .moveIntoVisibleRegion
        stackAppearance = .flat
    }
}
