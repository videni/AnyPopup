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
                ).inset(by: center.padding),
                config: center
            )
            return presentation(
                frame: frame,
                config: center,
                drag: disabledDrag,
                stackAppearance: center.stackAppearance,
                layoutTransition: config.layoutTransition,
                zIndex: zIndex
            )
        case let .top(top):
            let frame = ContainerPopupGeometry.top(
                contentSize: contentSize,
                availableFrame: availableFrame(
                    environment: environment,
                    safeArea: top.safeArea,
                    keyboardAvoidance: .none
                ).inset(by: top.padding),
                config: top
            )
            return presentation(
                frame: frame,
                config: top,
                drag: top.drag,
                stackAppearance: top.stackAppearance,
                layoutTransition: config.layoutTransition,
                zIndex: zIndex
            )
        case let .bottom(bottom):
            let frame = ContainerPopupGeometry.bottom(
                contentSize: contentSize,
                availableFrame: availableFrame(
                    environment: environment,
                    safeArea: bottom.safeArea,
                    keyboardAvoidance: bottom.keyboardAvoidance
                ).inset(by: bottom.padding),
                config: bottom
            )
            return presentation(
                frame: frame,
                config: bottom,
                drag: bottom.drag,
                stackAppearance: bottom.stackAppearance,
                layoutTransition: config.layoutTransition,
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
        guard PopupGeometryValidation.isValidAnchorFrame(anchorFrame) else {
            throw PopupPresentationError.invalidAnchorFrame
        }

        let resolved = config.resolve(in: environment, defaults: defaults.anchored).configuration
        let geometry = AnchoredPopupGeometry.resolve(
            contentSize: contentSize,
            anchorFrame: anchorFrame,
            containerFrame: safeAreaFrame(environment).inset(by: resolved.padding),
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
        layoutTransition: PopupTransition = .identity,
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
            layoutTransition: layoutTransition,
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
        case let .ignoring(edges):
            safeAreaInsets = EdgeInsets(
                top: edges.contains(.top) ? 0 : environment.safeArea.top,
                leading: edges.contains(.leading) ? 0 : environment.safeArea.leading,
                bottom: edges.contains(.bottom) ? 0 : environment.safeArea.bottom,
                trailing: edges.contains(.trailing) ? 0 : environment.safeArea.trailing
            )
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

}

private extension CGRect {
    func inset(by insets: EdgeInsets) -> CGRect {
        let originX = min(maxX, minX + max(0, insets.leading))
        let originY = min(maxY, minY + max(0, insets.top))
        let farX = max(originX, maxX - max(0, insets.trailing))
        let farY = max(originY, maxY - max(0, insets.bottom))
        return CGRect(
            x: originX,
            y: originY,
            width: farX - originX,
            height: farY - originY
        )
    }
}
