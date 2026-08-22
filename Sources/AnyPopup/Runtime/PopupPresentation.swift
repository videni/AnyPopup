import SwiftUI

public struct PopupTransform: Sendable, Equatable {
    public let translation: CGSize
    public let scale: CGFloat

    public static let identity = Self(translation: .zero, scale: 1)

    public init(translation: CGSize, scale: CGFloat) {
        self.translation = translation
        self.scale = scale
    }
}

public struct PopupPresentation: Sendable, Equatable {
    public let frame: CGRect
    public let transform: PopupTransform
    public let opacity: Double
    public let stackOverlayOpacity: Double
    public let zIndex: Double
    public let attachedEdges: Edge.Set
    public let corners: PopupCorners
    public let background: PopupBackground
    public let backdrop: BackdropPolicy
    public let insertionTransition: PopupTransition
    public let removalTransition: PopupTransition
    public let layoutTransition: PopupTransition
    public let drag: DragPolicy
    public let outsideInteraction: OutsideInteractionPolicy
    public let stackAppearance: StackAppearance
    public let anchoredGeometry: AnchoredPopupGeometry?
}

extension PopupPresentation {
    func applying(_ input: PopupLayoutInput) -> Self {
        let translatedFrame = frame.offsetBy(dx: 0, dy: input.verticalTranslation)
        let appearance = input.stackAppearance
        let scale = max(0, appearance.transform.scale)
        let scaledSize = CGSize(
            width: translatedFrame.width * scale,
            height: translatedFrame.height * scale
        )
        let adjustedFrame = CGRect(
            x: translatedFrame.midX - scaledSize.width / 2 + appearance.transform.translation.width,
            y: translatedFrame.midY - scaledSize.height / 2 + appearance.transform.translation.height,
            width: scaledSize.width,
            height: scaledSize.height
        )
        return Self(
            frame: adjustedFrame,
            transform: PopupTransform(
                translation: CGSize(
                    width: appearance.transform.translation.width,
                    height: appearance.transform.translation.height + input.verticalTranslation
                ),
                scale: scale
            ),
            opacity: opacity * appearance.opacity,
            stackOverlayOpacity: appearance.overlayOpacity,
            zIndex: zIndex,
            attachedEdges: attachedEdges,
            corners: corners,
            background: background,
            backdrop: backdrop,
            insertionTransition: insertionTransition,
            removalTransition: removalTransition,
            layoutTransition: layoutTransition,
            drag: drag,
            outsideInteraction: outsideInteraction,
            stackAppearance: stackAppearance,
            anchoredGeometry: anchoredGeometry
        )
    }
}
