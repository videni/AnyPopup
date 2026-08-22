import SwiftUI

public struct CenterPopupConfig: PopupConfiguration,
    PopupSizingConfigurable,
    PopupVisualConfigurable,
    PopupTransitionConfigurable,
    PopupOutsideInteractionConfigurable {
    private var explicitFields: Set<PopupConfigurationField> = []

    public var size: PopupSizePolicy { didSet { explicitFields.insert(.size) } }
    public var corners: PopupCorners { didSet { explicitFields.insert(.corners) } }
    public var background: PopupBackground { didSet { explicitFields.insert(.background) } }
    public var backdrop: BackdropPolicy { didSet { explicitFields.insert(.backdrop) } }
    public var insertionTransition: PopupTransition { didSet { explicitFields.insert(.insertionTransition) } }
    public var removalTransition: PopupTransition { didSet { explicitFields.insert(.removalTransition) } }
    public var outsideInteraction: OutsideInteractionPolicy { didSet { explicitFields.insert(.outsideInteraction) } }
    public var keyboardAvoidance: PopupKeyboardAvoidance { didSet { explicitFields.insert(.keyboardAvoidance) } }
    public var stackAppearance: StackAppearance { didSet { explicitFields.insert(.stackAppearance) } }

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

extension CenterPopupConfig {
    func applying(defaults: Self) -> Self {
        var result = self
        inherit(.size, defaults: defaults, result: &result, at: \.size)
        inherit(.corners, defaults: defaults, result: &result, at: \.corners)
        inherit(.background, defaults: defaults, result: &result, at: \.background)
        inherit(.backdrop, defaults: defaults, result: &result, at: \.backdrop)
        inherit(.insertionTransition, defaults: defaults, result: &result, at: \.insertionTransition)
        inherit(.removalTransition, defaults: defaults, result: &result, at: \.removalTransition)
        inherit(.outsideInteraction, defaults: defaults, result: &result, at: \.outsideInteraction)
        inherit(.keyboardAvoidance, defaults: defaults, result: &result, at: \.keyboardAvoidance)
        inherit(.stackAppearance, defaults: defaults, result: &result, at: \.stackAppearance)
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
