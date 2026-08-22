import SwiftUI

public struct PopupEnvironment: Sendable, Equatable {
    public let containerSize: CGSize
    public let safeArea: EdgeInsets
    public let keyboardOcclusionHeight: CGFloat
    public let accessibilityReduceMotion: Bool

    public init(
        containerSize: CGSize,
        safeArea: EdgeInsets,
        keyboardOcclusionHeight: CGFloat,
        accessibilityReduceMotion: Bool
    ) {
        self.containerSize = containerSize
        self.safeArea = safeArea
        self.keyboardOcclusionHeight = keyboardOcclusionHeight
        self.accessibilityReduceMotion = accessibilityReduceMotion
    }

    public var availableWidth: CGFloat {
        max(0, containerSize.width - safeArea.leading - safeArea.trailing)
    }

    public var availableHeight: CGFloat {
        max(
            0,
            containerSize.height
                - safeArea.top
                - safeArea.bottom
                - keyboardOcclusionHeight
        )
    }
}

private struct PopupContainerSizeKey: EnvironmentKey {
    static let defaultValue = CGSize.zero
}

private struct PopupAnchoredGeometryKey: EnvironmentKey {
    static let defaultValue: AnchoredPopupGeometry? = nil
}

public extension EnvironmentValues {
    var popupContainerSize: CGSize {
        get { self[PopupContainerSizeKey.self] }
        set { self[PopupContainerSizeKey.self] = newValue }
    }

    /// Anchored popup 最终屏幕避让结果。Container popup 中为 `nil`。
    var popupAnchoredGeometry: AnchoredPopupGeometry? {
        get { self[PopupAnchoredGeometryKey.self] }
        set { self[PopupAnchoredGeometryKey.self] = newValue }
    }
}
