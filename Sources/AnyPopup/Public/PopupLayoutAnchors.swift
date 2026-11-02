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
        anchorPreference(key: PopupLayoutAnchorPreference.self, value: .bounds) {
            [PopupLayoutAnchorKey(popupStackID: popupStackID, anchorID: anchorID): $0]
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
    let defaults: PopupDefaults
    let interactionMap: PopupInteractionMap
    var isVisible = true
    @State private var sceneSessionID = ""
    #if canImport(UIKit)
    @StateObject private var keyboardObserver = PopupKeyboardObserver()
    #endif
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        content.overlayPreferenceValue(PopupLayoutAnchorPreference.self) { anchors in
            GeometryReader { proxy in
                let frames = Dictionary(uniqueKeysWithValues: anchors.compactMap { key, anchor -> (String, CGRect)? in
                    guard key.popupStackID == popupStack.id else { return nil }
                    let frame = proxy[anchor]
                    guard PopupGeometryValidation.isValidAnchorFrame(frame) else { return nil }
                    return (key.anchorID, frame)
                })
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
                    #if canImport(UIKit)
                    .background(PopupLayoutAttachment(popupStack: popupStack, interactionMap: interactionMap,
                        keyboardObserver: keyboardObserver, sceneSessionID: $sceneSessionID, isVisible: isVisible)
                        .allowsHitTesting(false))
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
