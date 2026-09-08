import SwiftUI

public struct PopupView: View {
    @ObservedObject private var popupStack: PopupStack
    @ObservedObject private var anchorRegistry: AnchorRegistry
    @ObservedObject private var dismissalCoordinator: PopupDismissalCoordinator
    @StateObject private var presentationStore: PopupPresentationStore
    @State private var verticalInteractionStates: [PopupID: PopupVerticalInteractionState] = [:]

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
        _presentationStore = StateObject(wrappedValue: PopupPresentationStore())
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
        let renderEntries = PopupRenderEntry.resolve(
            active: popups,
            dismissing: dismissalSnapshots
        )
        let stackAppearances = resolvedStackAppearances(for: popups)
        let inputs = popups.map { popup in
            layoutInput(
                popup,
                stackAppearance: stackAppearances[popup.id] ?? .identity
            )
        }
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
        PopupLayout(
            inputs: inputs,
            environment: environment,
            defaults: defaults,
            interactionMap: interactionMap,
            presentationStore: presentationStore
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

            ForEach(renderEntries) { entry in
                let popup = entry.popup
                let snapshot = entry.snapshot
                let chrome = snapshot.map { PopupChrome($0.presentation) }
                    ?? resolvedChrome(for: popup.configuration)
                let activeAppearance = stackAppearances[popup.id] ?? .identity
                let overlayOpacity = snapshot?.presentation.stackOverlayOpacity
                    ?? activeAppearance.overlayOpacity
                let opacity = snapshot?.presentation.opacity ?? activeAppearance.opacity
                let verticalConfiguration = snapshot == nil
                    ? resolvedVerticalConfiguration(for: popup.configuration)
                    : nil
                entry.popup.body
                    .environment(
                        \.popupAnchoredGeometry,
                        snapshot?.presentation.anchoredGeometry
                            ?? presentationStore.anchoredGeometry(for: popup.id)
                    )
                    .modifier(PopupChromeModifier(
                        chrome: chrome,
                        stackOverlayOpacity: overlayOpacity,
                        fillsResolvedFrame: PopupRenderSizingPolicy.fillsResolvedFrame(
                            for: popup.configuration
                        ),
                        renderRole: snapshot == nil ? .live : .dismissalSnapshot
                    ))
                    .opacity(opacity)
                    .simultaneousGesture(
                        verticalDragGesture(
                            popup: popup,
                            configuration: verticalConfiguration
                        ),
                        including: entry.activeIndex == topIndex
                            && verticalConfiguration?.dragConfiguration.isEnabled == true
                            ? .all
                            : .none
                    )
                    .modifier(PopupRemovalEffect(
                        transition: snapshot?.presentation.removalTransition ?? .identity,
                        isDeparting: entry.phase == .departing,
                        containerSize: environment.containerSize
                    ))
                    .popupLayoutRole(layoutRole(for: entry))
                    .allowsHitTesting(snapshot == nil)
                    .zIndex(entry.zIndex * 3 + 2)
                    .task(id: entry.dismissalTaskID) {
                        guard let snapshot else { return }
                        await startDismissal(snapshot)
                    }
            }
        }
        .frame(
            width: environment.containerSize.width,
            height: environment.containerSize.height
        )
        .clipped()
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
        .onChange(of: popups.map(\.id)) { _, activeIDs in
            verticalInteractionStates = verticalInteractionStates.filter {
                activeIDs.contains($0.key)
            }
        }
        .onChange(of: environment.containerSize) {
            verticalInteractionStates.removeAll()
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
    func layoutRole(for entry: PopupRenderEntry) -> PopupLayoutRole {
        guard let snapshot = entry.snapshot else {
            return .popup(entry.id)
        }
        return .dismissalPopup(snapshot.id, snapshot.presentation.frame)
    }

    func layoutInput(
        _ popup: AnyPopup,
        stackAppearance: PopupStackItemAppearance
    ) -> PopupLayoutInput {
        let interactionState = verticalInteractionStates[popup.id]
        return PopupLayoutInput(
            id: popup.id,
            configuration: popup.configuration,
            anchorFrame: anchorFrame(for: popup),
            heightOverride: interactionState?.heightOverride,
            verticalTranslation: interactionState?.translation ?? 0,
            stackAppearance: stackAppearance
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

private extension PopupView {
    func resolvedVerticalConfiguration(
        for configuration: AnyPopupConfiguration
    ) -> ResolvedVerticalPopupConfiguration? {
        guard case let .container(config) = configuration else { return nil }
        switch config.resolve(in: environment, defaults: defaults).presentation {
        case .center:
            return nil
        case let .top(value):
            return ResolvedVerticalPopupConfiguration(
                dragConfiguration: value.dragConfiguration,
                stackAppearance: value.stackAppearance
            )
        case let .bottom(value):
            return ResolvedVerticalPopupConfiguration(
                dragConfiguration: value.dragConfiguration,
                stackAppearance: value.stackAppearance
            )
        }
    }

    func resolvedStackAppearances(
        for popups: [AnyPopup]
    ) -> [PopupID: PopupStackItemAppearance] {
        var result = Dictionary(uniqueKeysWithValues: popups.map {
            ($0.id, PopupStackItemAppearance.identity)
        })
        guard let topPopup = popups.last,
            let topConfiguration = resolvedVerticalConfiguration(
                for: topPopup.configuration
            ) else { return result }

        var group: [(AnyPopup, ResolvedVerticalPopupConfiguration)] = []
        for popup in popups.reversed() {
            guard let configuration = resolvedVerticalConfiguration(
                for: popup.configuration
            ), configuration.dragConfiguration.edge == topConfiguration.dragConfiguration.edge else {
                break
            }
            group.append((popup, configuration))
        }
        group.reverse()

        let translation = verticalInteractionStates[topPopup.id]?.translation ?? 0
        let outwardTranslation: CGFloat = switch topConfiguration.dragConfiguration.edge {
        case .top: max(0, -translation)
        case .bottom: max(0, translation)
        }
        let progress = outwardTranslation / max(1, environment.availableHeight)
        let appearances = topConfiguration.stackAppearance.resolve(
            popupCount: group.count,
            edge: topConfiguration.dragConfiguration.edge,
            activeDismissalProgress: progress
        )
        for ((popup, _), appearance) in zip(group, appearances) {
            result[popup.id] = appearance
        }
        return result
    }

    func verticalDragGesture(
        popup: AnyPopup,
        configuration: ResolvedVerticalPopupConfiguration?
    ) -> some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .global)
            .onChanged { value in
                updateVerticalDrag(
                    popup: popup,
                    configuration: configuration,
                    value: value
                )
            }
            .onEnded { value in
                endVerticalDrag(
                    popup: popup,
                    configuration: configuration,
                    value: value
                )
            }
    }

    func updateVerticalDrag(
        popup: AnyPopup,
        configuration: ResolvedVerticalPopupConfiguration?,
        value: DragGesture.Value
    ) {
        guard let configuration,
            configuration.dragConfiguration.isEnabled,
            let presentation = interactionMap.snapshot().presentations.last(where: {
                $0.id == popup.id
            })?.presentation else { return }

        var state = verticalInteractionStates[popup.id] ?? PopupVerticalInteractionState()
        if !state.isTracking {
            let startHeight = state.heightOverride ?? presentation.frame.height
            let localStartLocation = DragController.localStartLocation(
                globalLocation: value.startLocation.y,
                popupFrame: presentation.frame
            )
            guard DragController.isValidStart(
                location: localStartLocation,
                extent: startHeight,
                configuration: configuration.dragConfiguration
            ) else { return }
            state.isTracking = true
            state.gestureStartHeight = startHeight
            state.contentHeight = state.contentHeight ?? startHeight
        }
        state.translation = constrainedTranslation(
            value.translation.height,
            configuration: configuration.dragConfiguration
        )
        verticalInteractionStates[popup.id] = state
    }

    func endVerticalDrag(
        popup: AnyPopup,
        configuration: ResolvedVerticalPopupConfiguration?,
        value: DragGesture.Value
    ) {
        guard let configuration,
            var state = verticalInteractionStates[popup.id],
            state.isTracking,
            let currentHeight = state.gestureStartHeight,
            let contentHeight = state.contentHeight else { return }

        let projectedDelta = value.predictedEndTranslation.height - value.translation.height
        let velocity = projectedDelta / 0.15
        let resolution = DragController.resolve(
            translation: value.translation.height,
            velocity: velocity,
            extent: max(1, environment.availableHeight),
            currentHeight: currentHeight,
            contentHeight: contentHeight,
            configuration: configuration.dragConfiguration,
            largeExtent: environment.availableHeight
        )
        state.isTracking = false
        state.gestureStartHeight = nil

        switch resolution {
        case .dismiss:
            _ = popupStack.removePopupAndAbove(popup.id)
        case .cancel:
            state.translation = 0
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                verticalInteractionStates[popup.id] = state
            }
        case let .snap(height):
            state.translation = 0
            state.heightOverride = height
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                verticalInteractionStates[popup.id] = state
            }
        }
    }

    func constrainedTranslation(
        _ translation: CGFloat,
        configuration: PopupDragConfiguration
    ) -> CGFloat {
        let extent = max(1, environment.availableHeight)
        guard !configuration.detents.isEmpty else {
            return switch configuration.edge {
            case .top: max(-extent, min(0, translation))
            case .bottom: min(extent, max(0, translation))
            }
        }
        return min(extent, max(-extent, translation))
    }
}

private struct ResolvedVerticalPopupConfiguration {
    let dragConfiguration: PopupDragConfiguration
    let stackAppearance: StackAppearance
}

private struct PopupVerticalInteractionState {
    var heightOverride: CGFloat?
    var translation: CGFloat = 0
    var gestureStartHeight: CGFloat?
    var contentHeight: CGFloat?
    var isTracking = false
}

private struct PopupChrome {
    let corners: PopupCorners
    let background: PopupBackground
    let backdrop: BackdropPolicy
    let insertionTransition: PopupTransition
    let removalTransition: PopupTransition
    let stackOverlayOpacity: Double

    init<Config>(_ config: Config) where Config: PopupVisualConfigurable,
        Config: PopupTransitionConfigurable {
        corners = config.corners
        background = config.background
        backdrop = config.backdrop
        insertionTransition = config.insertionTransition
        removalTransition = config.removalTransition
        stackOverlayOpacity = 0
    }

    init(_ presentation: PopupPresentation) {
        corners = presentation.corners
        background = presentation.background
        backdrop = presentation.backdrop
        insertionTransition = presentation.insertionTransition
        removalTransition = presentation.removalTransition
        stackOverlayOpacity = presentation.stackOverlayOpacity
    }
}

private struct PopupChromeModifier: ViewModifier {
    let chrome: PopupChrome
    var stackOverlayOpacity: Double? = nil
    let fillsResolvedFrame: Bool
    var renderRole: PopupRenderRole = .live

    @ViewBuilder
    func body(content: Content) -> some View {
        let transitionPlan = renderRole.transitionPlan(
            insertion: chrome.insertionTransition,
            removal: chrome.removalTransition
        )
        switch chrome.background {
        case .none:
            if fillsResolvedFrame {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(
                        .asymmetric(
                            insertion: transitionPlan.insertion.anyTransition,
                            removal: transitionPlan.removal.anyTransition
                        )
                    )
            } else {
                content
                    .transition(
                        .asymmetric(
                            insertion: transitionPlan.insertion.anyTransition,
                            removal: transitionPlan.removal.anyTransition
                        )
                    )
            }
        case .color:
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(PopupBackgroundView(background: chrome.background))
                .overlay(
                    Color.black
                        .opacity(stackOverlayOpacity ?? chrome.stackOverlayOpacity)
                        .allowsHitTesting(false)
                )
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
                        insertion: transitionPlan.insertion.anyTransition,
                        removal: transitionPlan.removal.anyTransition
                    )
                )
        }
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

enum PopupRenderSizingPolicy {
    static func fillsResolvedFrame(for configuration: AnyPopupConfiguration) -> Bool {
        switch configuration {
        case .container:
            true
        case .anchored:
            false
        }
    }
}

struct PopupRenderTransitionPlan: Equatable {
    let insertion: PopupTransition
    let removal: PopupTransition
}

enum PopupRenderRole {
    case live
    case dismissalSnapshot

    func transitionPlan(
        insertion: PopupTransition,
        removal: PopupTransition
    ) -> PopupRenderTransitionPlan {
        switch self {
        case .live:
            PopupRenderTransitionPlan(insertion: insertion, removal: .identity)
        case .dismissalSnapshot:
            PopupRenderTransitionPlan(insertion: .identity, removal: .identity)
        }
    }
}

private struct PopupBackgroundView: View {
    let background: PopupBackground

    @ViewBuilder
    var body: some View {
        switch background {
        case .none:
            EmptyView()
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
