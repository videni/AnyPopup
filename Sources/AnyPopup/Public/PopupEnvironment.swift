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
