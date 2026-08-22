import SwiftUI

public enum PopupPresentationError: Error, Sendable, Equatable {
    case missingAnchorFrame
    case invalidAnchorFrame
}

public enum PopupPresentationResolver {
    public static func resolve(
        config: ContainerPopupConfig,
        environment: PopupEnvironment,
        contentSize: CGSize,
        defaults: PopupDefaults = PopupDefaults(),
        zIndex: Double = 0
    ) -> PopupPresentation {
        let resolved = config.resolve(in: environment, defaults: defaults)
        switch resolved.presentation {
        case let .center(center):
            let frame = ContainerPopupGeometry.center(
                contentSize: contentSize,
                availableFrame: availableFrame(
                    environment: environment,
                    safeArea: .contained,
                    keyboardAvoidance: center.keyboardAvoidance
                ),
                config: center
            )
            return presentation(
                frame: frame,
                config: center,
                drag: disabledDrag,
                stackAppearance: center.stackAppearance,
                zIndex: zIndex
            )
        case let .top(top):
            let frame = ContainerPopupGeometry.top(
                contentSize: contentSize,
                availableFrame: availableFrame(
                    environment: environment,
                    safeArea: top.safeArea,
                    keyboardAvoidance: .none
                ),
                config: top
            )
            return presentation(
                frame: frame,
                config: top,
                drag: top.drag,
                stackAppearance: top.stackAppearance,
                zIndex: zIndex
            )
        case let .bottom(bottom):
            let frame = ContainerPopupGeometry.bottom(
                contentSize: contentSize,
                availableFrame: availableFrame(
                    environment: environment,
                    safeArea: bottom.safeArea,
                    keyboardAvoidance: bottom.keyboardAvoidance
                ),
                config: bottom
            )
            return presentation(
                frame: frame,
                config: bottom,
                drag: bottom.drag,
                stackAppearance: bottom.stackAppearance,
                zIndex: zIndex
            )
        }
    }

    public static func resolve(
        config: AnchoredPopupConfig,
        environment: PopupEnvironment,
        contentSize: CGSize,
        anchorFrame: CGRect?,
        defaults: PopupDefaults = PopupDefaults(),
        zIndex: Double = 0
    ) throws -> PopupPresentation {
        guard let anchorFrame else {
            throw PopupPresentationError.missingAnchorFrame
        }
        guard isValidAnchorFrame(anchorFrame) else {
            throw PopupPresentationError.invalidAnchorFrame
        }

        let resolved = config.applying(defaults: defaults.anchored)
        let geometry = AnchoredPopupGeometry.resolve(
            contentSize: contentSize,
            anchorFrame: anchorFrame,
            containerFrame: safeAreaFrame(environment),
            config: resolved
        )
        return presentation(
            frame: geometry.frame,
            config: resolved,
            drag: disabledDrag,
            stackAppearance: .flat,
            zIndex: zIndex,
            anchoredGeometry: geometry
        )
    }
}

private extension PopupPresentationResolver {
    static let disabledDrag = DragPolicy(isEnabled: false, direction: .down)

    static func presentation<Config>(
        frame: CGRect,
        config: Config,
        drag: DragPolicy,
        stackAppearance: StackAppearance,
        zIndex: Double,
        anchoredGeometry: AnchoredPopupGeometry? = nil
    ) -> PopupPresentation where Config: PopupVisualConfigurable,
        Config: PopupTransitionConfigurable,
        Config: PopupOutsideInteractionConfigurable {
        PopupPresentation(
            frame: frame,
            transform: .identity,
            opacity: 1,
            zIndex: zIndex,
            attachedEdges: config.corners.attachedEdges,
            corners: config.corners,
            background: config.background,
            backdrop: config.backdrop,
            insertionTransition: config.insertionTransition,
            removalTransition: config.removalTransition,
            layoutTransition: .identity,
            drag: drag,
            outsideInteraction: config.outsideInteraction,
            stackAppearance: stackAppearance,
            anchoredGeometry: anchoredGeometry
        )
    }

    static func availableFrame(
        environment: PopupEnvironment,
        safeArea: PopupSafeAreaPolicy,
        keyboardAvoidance: PopupKeyboardAvoidance
    ) -> CGRect {
        let safeAreaInsets: EdgeInsets
        switch safeArea {
        case .contained:
            safeAreaInsets = environment.safeArea
        case .ignored:
            safeAreaInsets = EdgeInsets()
        }
        let keyboardHeight: CGFloat
        switch keyboardAvoidance {
        case .none:
            keyboardHeight = 0
        case .moveIntoVisibleRegion, .respectVisibleBottom:
            keyboardHeight = environment.keyboardOcclusionHeight
        }

        return CGRect(
            x: safeAreaInsets.leading,
            y: safeAreaInsets.top,
            width: max(
                0,
                environment.containerSize.width
                    - safeAreaInsets.leading
                    - safeAreaInsets.trailing
            ),
            height: max(
                0,
                environment.containerSize.height
                    - safeAreaInsets.top
                    - safeAreaInsets.bottom
                    - keyboardHeight
            )
        )
    }

    static func safeAreaFrame(_ environment: PopupEnvironment) -> CGRect {
        availableFrame(
            environment: environment,
            safeArea: .contained,
            keyboardAvoidance: .none
        )
    }

    static func isValidAnchorFrame(_ frame: CGRect) -> Bool {
        !frame.isNull
            && !frame.isInfinite
            && frame.width > 0
            && frame.height > 0
            && frame.origin.x.isFinite
            && frame.origin.y.isFinite
            && frame.width.isFinite
            && frame.height.isFinite
    }
}
