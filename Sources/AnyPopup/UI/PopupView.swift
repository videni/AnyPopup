import SwiftUI

public struct PopupView: View {
    @ObservedObject private var popupStack: PopupStack
    @ObservedObject private var anchorRegistry: AnchorRegistry
    @ObservedObject private var dismissalCoordinator: PopupDismissalCoordinator

    public let interactionMap: PopupInteractionMap

    private let sceneSessionID: String
    private let environment: PopupEnvironment
    private let defaults: PopupDefaults
    private let onPassThrough: @MainActor (CGPoint, PopupID?) -> Void

    @MainActor
    public init(
        popupStack: PopupStack,
        sceneSessionID: String,
        environment: PopupEnvironment,
        defaults: PopupDefaults = PopupDefaults(),
        anchorRegistry: AnchorRegistry = .shared,
        interactionMap: PopupInteractionMap = PopupInteractionMap(),
        onPassThrough: @escaping @MainActor (CGPoint, PopupID?) -> Void = { _, _ in }
    ) {
        _popupStack = ObservedObject(wrappedValue: popupStack)
        _anchorRegistry = ObservedObject(wrappedValue: anchorRegistry)
        _dismissalCoordinator = ObservedObject(wrappedValue: popupStack.dismissalCoordinator)
        self.sceneSessionID = sceneSessionID
        self.environment = environment
        self.defaults = defaults
        self.interactionMap = interactionMap
        self.onPassThrough = onPassThrough
        popupStack.dismissalCoordinator.bindInteractionMap(interactionMap)
    }

    public var body: some View {
        let popups = popupStack.popups
        let dismissalSnapshots = dismissalCoordinator.snapshots
        let inputs = popups.map(layoutInput)
        let topIndex = max(0, popups.count - 1)
        let topOutsideInteraction = inputs.reversed().compactMap(
            resolvedOutsideInteraction
        ).first
        let shieldCapturesTouches = !dismissalSnapshots.isEmpty
            || topOutsideInteraction != .passThrough
        let shieldLevel = max(
            Double(topIndex),
            dismissalSnapshots.map(\.presentation.zIndex).max() ?? 0
        )
        let layoutAnimation = resolvedLayoutAnimation(for: inputs)

        PopupLayout(
            inputs: inputs,
            environment: environment,
            defaults: defaults,
            interactionMap: interactionMap
        ) {
            ForEach(Array(popups.enumerated()), id: \.element.id) { index, popup in
                let chrome = resolvedChrome(for: popup.configuration)
                if chrome.backdrop != .none {
                    PopupBackdrop(policy: chrome.backdrop)
                        .allowsHitTesting(false)
                        .popupLayoutRole(.backdrop(popup.id))
                        .zIndex(Double(index * 3))
                }
            }

            ForEach(dismissalSnapshots) { snapshot in
                if snapshot.presentation.backdrop != .none {
                    PopupBackdrop(policy: snapshot.presentation.backdrop)
                        .allowsHitTesting(false)
                        .modifier(PopupBackdropRemovalModifier(
                            isDeparting: snapshot.isDeparting
                        ))
                        .popupLayoutRole(.dismissalBackdrop(snapshot.id))
                        .zIndex(snapshot.presentation.zIndex * 3)
                }
            }

            PopupShield(onTap: routeOutsideInteraction)
                .popupLayoutRole(.shield)
                .allowsHitTesting(shieldCapturesTouches)
                .zIndex(shieldLevel * 3 + 1)

            ForEach(Array(popups.enumerated()), id: \.element.id) { index, popup in
                let chrome = resolvedChrome(for: popup.configuration)
                popup.body
                    .modifier(PopupChromeModifier(chrome: chrome))
                    .popupLayoutRole(.popup(popup.id))
                    .zIndex(Double(index * 3 + 2))
            }

            ForEach(dismissalSnapshots) { snapshot in
                snapshot.popup.body
                    .modifier(PopupChromeModifier(
                        chrome: PopupChrome(snapshot.presentation)
                    ))
                    .modifier(PopupRemovalEffect(
                        transition: snapshot.presentation.removalTransition,
                        isDeparting: snapshot.isDeparting,
                        containerSize: environment.containerSize
                    ))
                    .popupLayoutRole(.dismissalPopup(
                        snapshot.id,
                        snapshot.presentation.frame
                    ))
                    .allowsHitTesting(false)
                    .zIndex(snapshot.presentation.zIndex * 3 + 2)
                    .task {
                        await startDismissal(snapshot)
                    }
            }
        }
        .frame(
            width: environment.containerSize.width,
            height: environment.containerSize.height
        )
        .clipped()
        .animation(layoutAnimation, value: environment)
        .animation(
            environment.accessibilityReduceMotion ? nil : .easeInOut(duration: 0.3),
            value: popups.map(\.id)
        )
        .onAppear {
            dismissalCoordinator.configure(
                isRenderingActive: true,
                reduceMotion: environment.accessibilityReduceMotion
            )
        }
        .onChange(of: environment.accessibilityReduceMotion) { _, reduceMotion in
            dismissalCoordinator.configure(
                isRenderingActive: true,
                reduceMotion: reduceMotion
            )
        }
        .onDisappear {
            dismissalCoordinator.configure(
                isRenderingActive: false,
                reduceMotion: environment.accessibilityReduceMotion
            )
        }
    }
}

private extension PopupView {
    func layoutInput(_ popup: AnyPopup) -> PopupLayoutInput {
        PopupLayoutInput(
            id: popup.id,
            configuration: popup.configuration,
            anchorFrame: anchorFrame(for: popup)
        )
    }

    func anchorFrame(for popup: AnyPopup) -> CGRect? {
        switch popup.anchorSource {
        case let .frame(frame):
            frame
        case let .tracked(anchorID):
            anchorRegistry.frame(
                for: AnchorRegistry.Key(
                    sceneSessionID: sceneSessionID,
                    popupStackID: popupStack.id,
                    anchorID: anchorID
                )
            )
        case nil:
            nil
        }
    }

    func resolvedChrome(for configuration: AnyPopupConfiguration) -> PopupChrome {
        switch configuration {
        case let .container(config):
            switch config.resolve(in: environment, defaults: defaults).presentation {
            case let .center(value):
                PopupChrome(value)
            case let .top(value):
                PopupChrome(value)
            case let .bottom(value):
                PopupChrome(value)
            }
        case let .anchored(config):
            PopupChrome(config.resolve(in: environment, defaults: defaults.anchored).configuration)
        }
    }

    func resolvedOutsideInteraction(
        for input: PopupLayoutInput
    ) -> OutsideInteractionPolicy? {
        switch input.configuration {
        case let .container(config):
            return switch config.resolve(in: environment, defaults: defaults).presentation {
            case let .center(value):
                value.outsideInteraction
            case let .top(value):
                value.outsideInteraction
            case let .bottom(value):
                value.outsideInteraction
            }
        case let .anchored(config):
            guard let anchorFrame = input.anchorFrame,
                PopupGeometryValidation.isValidAnchorFrame(anchorFrame) else { return nil }
            return config.resolve(
                in: environment,
                defaults: defaults.anchored
            ).configuration.outsideInteraction
        }
    }

    func resolvedLayoutAnimation(for inputs: [PopupLayoutInput]) -> Animation? {
        guard !environment.accessibilityReduceMotion else { return nil }
        let transition = inputs.reversed().compactMap { input -> PopupTransition? in
            guard case let .container(config) = input.configuration,
                config.layoutTransition != .identity else { return nil }
            return config.layoutTransition
        }.first
        guard transition != nil else { return nil }
        return .easeInOut(duration: 0.3)
    }

    func routeOutsideInteraction(_ point: CGPoint) {
        switch interactionMap.action(at: point) {
        case .consume, .routeToPopup:
            break
        case let .passThrough(target):
            onPassThrough(point, target)
        case .dismissTop:
            popupStack.removeLast()
        case let .dismissSuffix(above: popupID):
            removePopupsAbove(popupID)
        case .dismissAll:
            popupStack.removeAll()
        }
    }

    func removePopupsAbove(_ popupID: PopupID) {
        guard let index = popupStack.popups.firstIndex(where: { $0.id == popupID }) else {
            return
        }
        let nextIndex = popupStack.popups.index(after: index)
        guard nextIndex < popupStack.popups.endIndex else { return }
        popupStack.removePopupAndAbove(popupStack.popups[nextIndex].id)
    }

    func startDismissal(_ snapshot: PopupDismissalSnapshot) async {
        guard dismissalCoordinator.claimStart(identity: snapshot.id) else { return }
        guard !environment.accessibilityReduceMotion,
            snapshot.presentation.removalTransition != .identity else {
            dismissalCoordinator.complete(identity: snapshot.id)
            return
        }

        await Task.yield()
        withAnimation(.easeInOut(duration: 0.3), completionCriteria: .logicallyComplete) {
            dismissalCoordinator.markDeparting(identity: snapshot.id)
        } completion: {
            dismissalCoordinator.complete(identity: snapshot.id)
        }
    }
}

private struct PopupChrome {
    let corners: PopupCorners
    let background: PopupBackground
    let backdrop: BackdropPolicy
    let insertionTransition: PopupTransition
    let removalTransition: PopupTransition

    init<Config>(_ config: Config) where Config: PopupVisualConfigurable,
        Config: PopupTransitionConfigurable {
        corners = config.corners
        background = config.background
        backdrop = config.backdrop
        insertionTransition = config.insertionTransition
        removalTransition = config.removalTransition
    }

    init(_ presentation: PopupPresentation) {
        corners = presentation.corners
        background = presentation.background
        backdrop = presentation.backdrop
        insertionTransition = presentation.insertionTransition
        removalTransition = presentation.removalTransition
    }
}

private struct PopupChromeModifier: ViewModifier {
    let chrome: PopupChrome

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PopupBackgroundView(background: chrome.background))
            .clipShape(
                UnevenRoundedRectangle(
                    cornerRadii: cornerRadii,
                    style: .continuous
                )
            )
            .contentShape(
                UnevenRoundedRectangle(
                    cornerRadii: cornerRadii,
                    style: .continuous
                )
            )
            .transition(
                .asymmetric(
                    insertion: chrome.insertionTransition.anyTransition,
                    removal: chrome.removalTransition.anyTransition
                )
            )
    }

    private var cornerRadii: RectangleCornerRadii {
        let edges = chrome.corners.attachedEdges
        let radius = chrome.corners.radius
        return RectangleCornerRadii(
            topLeading: edges.contains(.top) || edges.contains(.leading) ? 0 : radius,
            bottomLeading: edges.contains(.bottom) || edges.contains(.leading) ? 0 : radius,
            bottomTrailing: edges.contains(.bottom) || edges.contains(.trailing) ? 0 : radius,
            topTrailing: edges.contains(.top) || edges.contains(.trailing) ? 0 : radius
        )
    }
}

private struct PopupBackgroundView: View {
    let background: PopupBackground

    @ViewBuilder
    var body: some View {
        switch background {
        case let .color(color):
            color
        }
    }
}

private struct PopupBackdropRemovalModifier: ViewModifier {
    let isDeparting: Bool

    func body(content: Content) -> some View {
        content.opacity(isDeparting ? 0 : 1)
    }
}

private struct PopupRemovalEffect: ViewModifier {
    let transition: PopupTransition
    let isDeparting: Bool
    let containerSize: CGSize

    func body(content: Content) -> some View {
        content
            .offset(isDeparting ? targetOffset : .zero)
            .scaleEffect(isDeparting && transition == .scaleAndOpacity ? 0.85 : 1)
            .opacity(isDeparting && fades ? 0 : 1)
    }

    private var fades: Bool {
        transition == .opacity || transition == .scaleAndOpacity
    }

    private var targetOffset: CGSize {
        guard case let .moveFrom(edge) = transition else {
            guard case let .moveTo(edge) = transition else { return .zero }
            return offset(for: edge)
        }
        return offset(for: edge)
    }

    private func offset(for edge: Edge) -> CGSize {
        switch edge {
        case .top:
            CGSize(width: 0, height: -containerSize.height)
        case .bottom:
            CGSize(width: 0, height: containerSize.height)
        case .leading:
            CGSize(width: -containerSize.width, height: 0)
        case .trailing:
            CGSize(width: containerSize.width, height: 0)
        }
    }
}

private extension PopupTransition {
    var anyTransition: AnyTransition {
        switch self {
        case .identity:
            .identity
        case .opacity:
            .opacity
        case .scaleAndOpacity:
            .scale.combined(with: .opacity)
        case let .moveFrom(edge), let .moveTo(edge):
            .move(edge: edge)
        }
    }
}
