import CoreGraphics

public enum ContainerPopupKind: Sendable, Equatable {
    case center
    case top
    case bottom
}

public enum ContainerPopupPresentation: Sendable {
    case center(CenterPopupConfig)
    case top(TopPopupConfig)
    case bottom(BottomPopupConfig)

    public var kind: ContainerPopupKind {
        switch self {
        case .center: .center
        case .top: .top
        case .bottom: .bottom
        }
    }
}

public enum ContainerPopupCondition: Sendable, Equatable {
    case containerWidthLessThan(CGFloat)
    case containerHeightLessThan(CGFloat)
    case availableWidthLessThan(CGFloat)
    case availableHeightLessThan(CGFloat)
    case keyboardVisible
    case accessibilityReduceMotion

    func matches(_ environment: PopupEnvironment) -> Bool {
        switch self {
        case let .containerWidthLessThan(value):
            environment.containerSize.width < value
        case let .containerHeightLessThan(value):
            environment.containerSize.height < value
        case let .availableWidthLessThan(value):
            environment.availableWidth < value
        case let .availableHeightLessThan(value):
            environment.availableHeight < value
        case .keyboardVisible:
            environment.keyboardOcclusionHeight > 0
        case .accessibilityReduceMotion:
            environment.accessibilityReduceMotion
        }
    }
}

public struct ContainerPopupRule: Sendable {
    public let condition: ContainerPopupCondition
    public let presentation: ContainerPopupPresentation
}

public struct ResolvedContainerPopupConfiguration: Sendable {
    public let presentation: ContainerPopupPresentation
    public let matchedRuleIndices: [Int]

    public var kind: ContainerPopupKind {
        presentation.kind
    }
}

public struct ContainerPopupConfig: PopupConfiguration {
    public let defaultPresentation: ContainerPopupPresentation
    public let conditionalPresentations: [ContainerPopupRule]

    public static func center(_ config: CenterPopupConfig = .init()) -> Self {
        Self(defaultPresentation: .center(config), conditionalPresentations: [])
    }

    public static func top(_ config: TopPopupConfig = .init()) -> Self {
        Self(defaultPresentation: .top(config), conditionalPresentations: [])
    }

    public static func bottom(_ config: BottomPopupConfig = .init()) -> Self {
        Self(defaultPresentation: .bottom(config), conditionalPresentations: [])
    }

    public func when(
        _ condition: ContainerPopupCondition,
        use presentation: ContainerPopupPresentation
    ) -> Self {
        Self(
            defaultPresentation: defaultPresentation,
            conditionalPresentations: conditionalPresentations + [
                ContainerPopupRule(condition: condition, presentation: presentation)
            ]
        )
    }

    public func resolve(
        in environment: PopupEnvironment,
        defaults: PopupDefaults = PopupDefaults()
    ) -> ResolvedContainerPopupConfiguration {
        var selected = defaultPresentation
        var matchedRuleIndices: [Int] = []

        for (index, rule) in conditionalPresentations.enumerated()
        where rule.condition.matches(environment) {
            selected = rule.presentation
            matchedRuleIndices.append(index)
        }

        return ResolvedContainerPopupConfiguration(
            presentation: selected.applying(defaults: defaults),
            matchedRuleIndices: matchedRuleIndices
        )
    }

    private init(
        defaultPresentation: ContainerPopupPresentation,
        conditionalPresentations: [ContainerPopupRule]
    ) {
        self.defaultPresentation = defaultPresentation
        self.conditionalPresentations = conditionalPresentations
    }
}

private extension ContainerPopupPresentation {
    func applying(defaults: PopupDefaults) -> Self {
        switch self {
        case let .center(config):
            .center(config.applying(defaults: defaults.center))
        case let .top(config):
            .top(config.applying(defaults: defaults.top))
        case let .bottom(config):
            .bottom(config.applying(defaults: defaults.bottom))
        }
    }
}
