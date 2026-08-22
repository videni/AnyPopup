import SwiftUI

public struct AnchoredPopupConfig: PopupConfiguration,
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
    public var sourceAnchor: PopupAnchorPoint { didSet { explicitFields.insert(.sourceAnchor) } }
    public var popupAnchor: PopupAnchorPoint { didSet { explicitFields.insert(.popupAnchor) } }
    public var offset: CGSize { didSet { explicitFields.insert(.offset) } }
    public var screenAvoidance: ScreenAvoidancePolicy { didSet { explicitFields.insert(.screenAvoidance) } }

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

extension AnchoredPopupConfig {
    func applying(defaults: Self) -> Self {
        var result = self
        inherit(.size, defaults: defaults, result: &result, at: \.size)
        inherit(.corners, defaults: defaults, result: &result, at: \.corners)
        inherit(.background, defaults: defaults, result: &result, at: \.background)
        inherit(.backdrop, defaults: defaults, result: &result, at: \.backdrop)
        inherit(.insertionTransition, defaults: defaults, result: &result, at: \.insertionTransition)
        inherit(.removalTransition, defaults: defaults, result: &result, at: \.removalTransition)
        inherit(.outsideInteraction, defaults: defaults, result: &result, at: \.outsideInteraction)
        inherit(.sourceAnchor, defaults: defaults, result: &result, at: \.sourceAnchor)
        inherit(.popupAnchor, defaults: defaults, result: &result, at: \.popupAnchor)
        inherit(.offset, defaults: defaults, result: &result, at: \.offset)
        inherit(.screenAvoidance, defaults: defaults, result: &result, at: \.screenAvoidance)
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
