import SwiftUI

public struct BottomPopupConfig: PopupConfiguration,
    PopupSizingConfigurable,
    PopupVisualConfigurable,
    PopupTransitionConfigurable,
    PopupOutsideInteractionConfigurable,
    PopupDetentConfigurable {
    private var explicitFields: Set<PopupConfigurationField> = []

    public var size: PopupSizePolicy { didSet { explicitFields.insert(.size) } }
    public var corners: PopupCorners { didSet { explicitFields.insert(.corners) } }
    public var background: PopupBackground { didSet { explicitFields.insert(.background) } }
    public var backdrop: BackdropPolicy { didSet { explicitFields.insert(.backdrop) } }
    public var insertionTransition: PopupTransition { didSet { explicitFields.insert(.insertionTransition) } }
    public var removalTransition: PopupTransition { didSet { explicitFields.insert(.removalTransition) } }
    public var outsideInteraction: OutsideInteractionPolicy { didSet { explicitFields.insert(.outsideInteraction) } }
    public var safeArea: PopupSafeAreaPolicy { didSet { explicitFields.insert(.safeArea) } }
    public var drag: DragPolicy { didSet { explicitFields.insert(.drag) } }
    public var detents: [PopupDetent] { didSet { explicitFields.insert(.detents) } }
    public var stackAppearance: StackAppearance { didSet { explicitFields.insert(.stackAppearance) } }
    public var keyboardAvoidance: PopupKeyboardAvoidance { didSet { explicitFields.insert(.keyboardAvoidance) } }

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

extension BottomPopupConfig {
    func applying(defaults: Self) -> Self {
        var result = self
        inherit(.size, defaults: defaults, result: &result, at: \.size)
        inherit(.corners, defaults: defaults, result: &result, at: \.corners)
        inherit(.background, defaults: defaults, result: &result, at: \.background)
        inherit(.backdrop, defaults: defaults, result: &result, at: \.backdrop)
        inherit(.insertionTransition, defaults: defaults, result: &result, at: \.insertionTransition)
        inherit(.removalTransition, defaults: defaults, result: &result, at: \.removalTransition)
        inherit(.outsideInteraction, defaults: defaults, result: &result, at: \.outsideInteraction)
        inherit(.safeArea, defaults: defaults, result: &result, at: \.safeArea)
        inherit(.drag, defaults: defaults, result: &result, at: \.drag)
        inherit(.detents, defaults: defaults, result: &result, at: \.detents)
        inherit(.stackAppearance, defaults: defaults, result: &result, at: \.stackAppearance)
        inherit(.keyboardAvoidance, defaults: defaults, result: &result, at: \.keyboardAvoidance)
        return result
    }

    private func inherit<Value>(
        _ field: PopupConfigurationField,
        defaults: Self,
        result: inout Self,
        at keyPath: WritableKeyPath<Self, Value>
    ) {
        inheritPopupDefault(
            field,
            explicitFields: explicitFields,
            defaultExplicitFields: defaults.explicitFields,
            defaults: defaults,
            result: &result,
            at: keyPath
        )
    }
}
