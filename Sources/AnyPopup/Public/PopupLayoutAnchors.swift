import SwiftUI

struct PopupLayoutAnchorKey: Hashable {
    let popupStackID: PopupStackID
    let anchorID: String
}

struct PopupLayoutAnchorPreference: PreferenceKey {
    static var defaultValue: [PopupLayoutAnchorKey: Anchor<CGRect>] { [:] }

    static func reduce(value: inout [PopupLayoutAnchorKey: Anchor<CGRect>],
                       nextValue: () -> [PopupLayoutAnchorKey: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

public extension View {
    /// Associates the source with its view. Coordinates are resolved by the enclosing popup container.
    func popupAnchor(_ anchorID: String, popupStackID: PopupStackID = .shared) -> some View {
        transformAnchorPreference(key: PopupLayoutAnchorPreference.self, value: .bounds) { anchors, source in
            anchors[PopupLayoutAnchorKey(popupStackID: popupStackID, anchorID: anchorID)] = source
        }
    }

    /// Attach to a common ancestor of the source views; popup content stays in this view tree.
    func popupContainer(popupStack: PopupStack, defaults: PopupDefaults = PopupDefaults(), isVisible: Bool = true) -> some View {
        modifier(PopupLayoutContainerModifier(popupStack: popupStack, defaults: defaults, isVisible: isVisible))
    }
}

private struct PopupLayoutContainerModifier: ViewModifier {
    let popupStack: PopupStack
    let defaults: PopupDefaults
    let isVisible: Bool
    @State private var interactionMap = PopupInteractionMap()

    func body(content: Content) -> some View {
        PopupLayoutContainer(content: content, popupStack: popupStack,
            defaults: defaults, interactionMap: interactionMap, isVisible: isVisible)
    }
}

struct PopupLayoutContainer<Content: View>: View {
    let content: Content
    @ObservedObject var popupStack: PopupStack
    @ObservedObject private var dismissalCoordinator: PopupDismissalCoordinator
    let defaults: PopupDefaults
    let interactionMap: PopupInteractionMap
    var isVisible = true
    @State private var sceneSessionID = ""
    #if canImport(UIKit)
    @StateObject private var keyboardObserver = PopupKeyboardObserver()
    #endif
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(content: Content, popupStack: PopupStack, defaults: PopupDefaults,
         interactionMap: PopupInteractionMap, isVisible: Bool = true) {
        self.content = content
        self.popupStack = popupStack
        self.defaults = defaults
        self.interactionMap = interactionMap
        self.isVisible = isVisible
        _dismissalCoordinator = ObservedObject(wrappedValue: popupStack.dismissalCoordinator)
    }

    var body: some View {
        content.overlayPreferenceValue(PopupLayoutAnchorPreference.self) { anchors in
            GeometryReader { proxy in
                let frames = Dictionary(uniqueKeysWithValues: anchors.compactMap { key, anchor -> (String, CGRect)? in
                    guard key.popupStackID == popupStack.id else { return nil }
                    let frame = proxy[anchor]
                    guard PopupGeometryValidation.isValidAnchorFrame(frame) else { return nil }
                    return (key.anchorID, frame)
                })
                let hasRenderablePopup = popupStack.popups.contains { popup in
                    if case .container = popup.configuration { return true }
                    guard let frame = PopupAnchorFrameResolver.resolve(popup.anchorSource, frames: frames) else { return false }
                    return PopupGeometryValidation.isValidAnchorFrame(frame)
                }
                let shouldRender = hasRenderablePopup || !dismissalCoordinator.snapshots.isEmpty
                ZStack(alignment: .topLeading) {
                    if shouldRender {
                        PopupView(popupStack: popupStack, sceneSessionID: sceneSessionID,
                            environment: PopupEnvironment(containerSize: proxy.size, safeArea: proxy.safeAreaInsets,
                                keyboardOcclusionHeight: keyboardHeight, accessibilityReduceMotion: reduceMotion),
                            defaults: defaults, interactionMap: interactionMap, trackedAnchorFrames: frames)
                            .environment(\.popupContainerSize, proxy.size)
                            .environment(\.popupAnchorFrames, frames)
                            .environment(\.popupContainerStackID, popupStack.id)
                            .opacity(isVisible ? 1 : 0)
                            .allowsHitTesting(isVisible)
                            .accessibilityHidden(!isVisible)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                .onChange(of: shouldRender, initial: true) {
                    if !shouldRender { interactionMap.publish(.empty) }
                }
                #if canImport(UIKit)
                .background(alignment: .topLeading) {
                    // Registration needs an origin, not a full-screen native hit/accessibility surface.
                    PopupLayoutAttachment(popupStack: popupStack, interactionMap: interactionMap,
                        keyboardObserver: keyboardObserver, sceneSessionID: $sceneSessionID, isVisible: isVisible,
                        containerSize: proxy.size, safeAreaInsets: proxy.safeAreaInsets)
                        .frame(width: 0, height: 0)
                        // Only the bridge uses physical left-to-right axes; popup content keeps its direction.
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .environment(\.layoutDirection, .leftToRight)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { _ in
                    keyboardObserver.refreshGeometry()
                }
                #endif
            }
            .ignoresSafeArea(.keyboard)
        }
    }

    private var keyboardHeight: CGFloat {
        #if canImport(UIKit)
        keyboardObserver.occlusionHeight
        #else
        0
        #endif
    }
}

enum PopupAnchorFrameResolver {
    static func resolve(_ source: PopupAnchorSource?, frames: [String: CGRect]) -> CGRect? {
        switch source {
        case let .frame(frame): return frame
        case let .tracked(id): return frames[id]
        case let .aligned(horizontal, vertical):
            guard let x = frames[horizontal], let y = frames[vertical] else { return nil }
            return CGRect(x: x.minX, y: y.minY, width: x.width, height: y.height)
        case nil: return nil
        }
    }
}
