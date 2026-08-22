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

public struct ContainerPopupConfig: PopupConfiguration {
    public let defaultPresentation: ContainerPopupPresentation

    public static func center(_ config: CenterPopupConfig = .init()) -> Self {
        Self(defaultPresentation: .center(config))
    }

    public static func top(_ config: TopPopupConfig = .init()) -> Self {
        Self(defaultPresentation: .top(config))
    }

    public static func bottom(_ config: BottomPopupConfig = .init()) -> Self {
        Self(defaultPresentation: .bottom(config))
    }

    private init(defaultPresentation: ContainerPopupPresentation) {
        self.defaultPresentation = defaultPresentation
    }
}
