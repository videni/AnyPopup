import SwiftUI

public struct PopupView: View {
    @ObservedObject private var popupStack: PopupStack
    @ObservedObject private var anchorRegistry: AnchorRegistry

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
        self.sceneSessionID = sceneSessionID
        self.environment = environment
        self.defaults = defaults
        self.interactionMap = interactionMap
        self.onPassThrough = onPassThrough
    }

    public var body: some View {
        let popups = popupStack.popups
        let inputs = popups.map(layoutInput)
        let topIndex = max(0, popups.count - 1)

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

            PopupShield(onTap: routeOutsideInteraction)
                .popupLayoutRole(.shield)
                .zIndex(Double(topIndex * 3 + 1))

            ForEach(Array(popups.enumerated()), id: \.element.id) { index, popup in
                let chrome = resolvedChrome(for: popup.configuration)
                popup.body
                    .modifier(PopupChromeModifier(chrome: chrome))
                    .popupLayoutRole(.popup(popup.id))
                    .zIndex(Double(index * 3 + 2))
            }
        }
        .frame(
            width: environment.containerSize.width,
            height: environment.containerSize.height
        )
        .clipped()
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
            PopupChrome(config.applying(defaults: defaults.anchored))
        }
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
