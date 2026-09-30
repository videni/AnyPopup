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

private struct PopupPresentedKey: EnvironmentKey {
    static let defaultValue = false
}

private struct PopupDragDismissalProgressKey: EnvironmentKey {
    static let defaultValue: Double? = nil
}

public extension EnvironmentValues {
    /// Progress below a continuous sheet's closing line while its handle is being dragged.
    /// Nil means releasing the handle will keep the sheet open.
    var popupDragDismissalProgress: Double? {
        get { self[PopupDragDismissalProgressKey.self] }
        set { self[PopupDragDismissalProgressKey.self] = newValue }
    }

    /// True after the popup's insertion animation completes, while it remains active.
    var isPopupPresented: Bool {
        get { self[PopupPresentedKey.self] }
        set { self[PopupPresentedKey.self] = newValue }
    }

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
