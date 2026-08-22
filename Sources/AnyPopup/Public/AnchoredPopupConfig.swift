import SwiftUI

public struct AnchoredPopupConfig: PopupConfiguration,
    PopupSizingConfigurable,
    PopupPaddingConfigurable,
    PopupVisualConfigurable,
    PopupTransitionConfigurable,
    PopupOutsideInteractionConfigurable {
    private var explicitFields: Set<PopupConfigurationField> = []
    public private(set) var conditionalRules: [AnchoredPopupRule] = []

    public var size: PopupSizePolicy { didSet { explicitFields.insert(.size) } }
    public var padding: EdgeInsets { didSet { explicitFields.insert(.padding) } }
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
        padding = EdgeInsets()
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

    public func originAnchor(_ anchor: PopupAnchorPoint) -> Self {
        var copy = self
        copy.sourceAnchor = anchor
        return copy
    }

    public func popupAnchor(_ anchor: PopupAnchorPoint) -> Self {
        var copy = self
        copy.popupAnchor = anchor
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

    public func edgePadding(_ value: CGFloat, edges: Edge.Set = .horizontal) -> Self {
        screenAvoidance(edges: edges, padding: value)
    }

    public func tapOutsideBehavior(_ behavior: TapOutsideBehavior) -> Self {
        let policy: OutsideInteractionPolicy = switch behavior {
        case .none: .consume
        case .dismiss: .dismissTop
        case .passThrough: .passThrough
        }
        return outsideInteraction(policy)
    }

    public func when(_ condition: PopupCondition, use config: Self) -> Self {
        var copy = self
        copy.conditionalRules.append(
            AnchoredPopupRule(condition: condition, configuration: config.withoutConditionalRules())
        )
        return copy
    }

    public func resolve(
        in environment: PopupEnvironment,
        defaults: AnchoredPopupConfig = AnchoredPopupConfig()
    ) -> ResolvedAnchoredPopupConfiguration {
        var selected = withoutConditionalRules()
        var matchedRuleIndices: [Int] = []

        for (index, rule) in conditionalRules.enumerated()
        where rule.condition.matches(environment) {
            selected = rule.configuration
            matchedRuleIndices.append(index)
        }

        return ResolvedAnchoredPopupConfiguration(
            configuration: selected.applying(defaults: defaults.withoutConditionalRules()),
            matchedRuleIndices: matchedRuleIndices
        )
    }
}

public struct AnchoredPopupRule: Sendable {
    public let condition: PopupCondition
    private let storedConfiguration: AnchoredPopupRuleConfiguration

    fileprivate var configuration: AnchoredPopupConfig {
        switch storedConfiguration {
        case let .value(configuration):
            configuration
        }
    }

    fileprivate init(condition: PopupCondition, configuration: AnchoredPopupConfig) {
        self.condition = condition
        storedConfiguration = .value(configuration)
    }
}

public struct ResolvedAnchoredPopupConfiguration: Sendable {
    public let configuration: AnchoredPopupConfig
    public let matchedRuleIndices: [Int]
}

private indirect enum AnchoredPopupRuleConfiguration: Sendable {
    case value(AnchoredPopupConfig)
}

extension AnchoredPopupConfig {
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
        inherit(.sourceAnchor, defaults: defaults, result: &result, at: \.sourceAnchor)
        inherit(.popupAnchor, defaults: defaults, result: &result, at: \.popupAnchor)
        inherit(.offset, defaults: defaults, result: &result, at: \.offset)
        inherit(.screenAvoidance, defaults: defaults, result: &result, at: \.screenAvoidance)
        return result
    }

    func withoutConditionalRules() -> Self {
        var copy = self
        copy.conditionalRules = []
        return copy
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
