import SwiftUI

public struct TopPopupConfig: PopupConfiguration,
    PopupSizingConfigurable,
    PopupPaddingConfigurable,
    PopupVisualConfigurable,
    PopupTransitionConfigurable,
    PopupOutsideInteractionConfigurable,
    PopupDetentConfigurable,
    PopupSafeAreaConfigurable,
    PopupDragConfigurable,
    PopupStackAppearanceConfigurable {
    private var explicitFields: Set<PopupConfigurationField> = []

    public var size: PopupSizePolicy { didSet { explicitFields.insert(.size) } }
    public var padding: EdgeInsets { didSet { explicitFields.insert(.padding) } }
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

    public init() {
        size = .content
        padding = EdgeInsets()
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

public extension TopPopupConfig {
    var dragConfiguration: PopupDragConfiguration {
        .top(
            isEnabled: drag.isEnabled,
            activationArea: drag.activationArea,
            dismissalThreshold: drag.dismissalThreshold,
            detents: detents
        )
    }
}

extension TopPopupConfig {
    func applying(defaults: Self) -> Self {
        var result = self
        inherit(.size, defaults: defaults, result: &result, at: \.size)
        inherit(.padding, defaults: defaults, result: &result, at: \.padding)
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
