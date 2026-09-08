import SwiftUI

struct PopupViewport: Sendable, Equatable {
    let containerSize: CGSize
    let systemSafeArea: EdgeInsets
    let keyboardOcclusionHeight: CGFloat

    func environment(reduceMotion: Bool) -> PopupEnvironment {
        PopupEnvironment(
            containerSize: containerSize,
            safeArea: systemSafeArea,
            keyboardOcclusionHeight: keyboardOcclusionHeight,
            accessibilityReduceMotion: reduceMotion
        )
    }
}
