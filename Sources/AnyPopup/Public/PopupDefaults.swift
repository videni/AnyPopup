public struct PopupDefaults: Sendable {
    public private(set) var center: CenterPopupConfig
    public private(set) var top: TopPopupConfig
    public private(set) var bottom: BottomPopupConfig
    public private(set) var anchored: AnchoredPopupConfig

    public init() {
        center = CenterPopupConfig()
        top = TopPopupConfig()
        bottom = BottomPopupConfig()
        anchored = AnchoredPopupConfig()
    }

    public func center(_ update: (CenterPopupConfig) -> CenterPopupConfig) -> Self {
        var copy = self
        copy.center = update(center)
        return copy
    }

    public func top(_ update: (TopPopupConfig) -> TopPopupConfig) -> Self {
        var copy = self
        copy.top = update(top)
        return copy
    }

    public func bottom(_ update: (BottomPopupConfig) -> BottomPopupConfig) -> Self {
        var copy = self
        copy.bottom = update(bottom)
        return copy
    }

    public func anchored(_ update: (AnchoredPopupConfig) -> AnchoredPopupConfig) -> Self {
        var copy = self
        copy.anchored = update(anchored)
        return copy
    }

    public func vertical(_ update: (VerticalPopupDefaults) -> VerticalPopupDefaults) -> Self {
        var copy = self
        let vertical = update(.init(top: top, bottom: bottom))
        copy.top = vertical.top
        copy.bottom = vertical.bottom
        return copy
    }
}

public struct VerticalPopupDefaults: Sendable {
    public private(set) var top: TopPopupConfig
    public private(set) var bottom: BottomPopupConfig

    public func corners(_ policy: PopupCorners) -> Self {
        var copy = self
        copy.top = top.corners(policy)
        copy.bottom = bottom.corners(policy)
        return copy
    }

    public func backdrop(_ policy: BackdropPolicy) -> Self {
        var copy = self
        copy.top = top.backdrop(policy)
        copy.bottom = bottom.backdrop(policy)
        return copy
    }

    public func outsideInteraction(_ policy: OutsideInteractionPolicy) -> Self {
        var copy = self
        copy.top = top.outsideInteraction(policy)
        copy.bottom = bottom.outsideInteraction(policy)
        return copy
    }

    public func drag(isEnabled: Bool) -> Self {
        var copy = self
        var topDrag = top.drag
        var bottomDrag = bottom.drag
        topDrag.isEnabled = isEnabled
        bottomDrag.isEnabled = isEnabled
        copy.top.drag = topDrag
        copy.bottom.drag = bottomDrag
        return copy
    }

    init(top: TopPopupConfig, bottom: BottomPopupConfig) {
        self.top = top
        self.bottom = bottom
    }
}
