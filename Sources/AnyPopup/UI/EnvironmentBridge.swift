import Combine
import Foundation
import SwiftUI

@MainActor
public final class PopupEnvironmentBridge: ObservableObject {
    @Published public private(set) var locale: Locale
    @Published public private(set) var layoutDirection: LayoutDirection
    @Published public private(set) var colorScheme: ColorScheme?
    @Published public private(set) var dynamicTypeSize: DynamicTypeSize
    @Published public private(set) var reduceMotion: Bool

    public init(
        locale: Locale = .current,
        layoutDirection: LayoutDirection = .leftToRight,
        colorScheme: ColorScheme? = nil,
        dynamicTypeSize: DynamicTypeSize = .large,
        reduceMotion: Bool = false
    ) {
        self.locale = locale
        self.layoutDirection = layoutDirection
        self.colorScheme = colorScheme
        self.dynamicTypeSize = dynamicTypeSize
        self.reduceMotion = reduceMotion
    }

    public func update(
        locale: Locale,
        layoutDirection: LayoutDirection,
        colorScheme: ColorScheme?,
        dynamicTypeSize: DynamicTypeSize,
        reduceMotion: Bool
    ) {
        if self.locale != locale { self.locale = locale }
        if self.layoutDirection != layoutDirection { self.layoutDirection = layoutDirection }
        if self.colorScheme != colorScheme { self.colorScheme = colorScheme }
        if self.dynamicTypeSize != dynamicTypeSize { self.dynamicTypeSize = dynamicTypeSize }
        if self.reduceMotion != reduceMotion { self.reduceMotion = reduceMotion }
    }

    public func popupEnvironment(
        containerSize: CGSize,
        safeArea: EdgeInsets,
        keyboardOcclusionHeight: CGFloat
    ) -> PopupEnvironment {
        PopupEnvironment(
            containerSize: containerSize,
            safeArea: safeArea,
            keyboardOcclusionHeight: keyboardOcclusionHeight,
            accessibilityReduceMotion: reduceMotion
        )
    }
}

enum PopupSceneGeometry {
    static func fullContainerSize(
        contentSize: CGSize,
        safeArea: EdgeInsets
    ) -> CGSize {
        CGSize(
            width: contentSize.width + safeArea.leading + safeArea.trailing,
            height: contentSize.height + safeArea.top + safeArea.bottom
        )
    }
}

enum PopupKeyboardGeometry {
    static func occlusionHeight(container: CGRect, safeAreaBottom: CGFloat, keyboard: CGRect) -> CGFloat {
        guard !container.isEmpty, !keyboard.isEmpty, !keyboard.isNull,
              keyboard.maxY >= container.maxY - 1,
              keyboard.maxX > container.minX, keyboard.minX < container.maxX else { return 0 }
        return max(0, min(container.height, container.maxY - keyboard.minY) - safeAreaBottom)
    }
}

#if canImport(UIKit)
import UIKit

struct PopupSceneRootView: View {
    let popupStack: PopupStack
    let sceneSessionID: String
    let defaults: PopupDefaults
    let interactionMap: PopupInteractionMap

    @ObservedObject var environmentBridge: PopupEnvironmentBridge
    @ObservedObject var keyboardObserver: PopupKeyboardObserver

    var body: some View {
        GeometryReader { proxy in
            let containerSize = PopupSceneGeometry.fullContainerSize(
                contentSize: proxy.size,
                safeArea: proxy.safeAreaInsets
            )
            PopupView(
                popupStack: popupStack,
                sceneSessionID: sceneSessionID,
                environment: environmentBridge.popupEnvironment(
                    containerSize: containerSize,
                    safeArea: proxy.safeAreaInsets,
                    keyboardOcclusionHeight: keyboardObserver.occlusionHeight
                ),
                defaults: defaults,
                interactionMap: interactionMap
            )
            .environment(\.popupContainerSize, containerSize)
            .ignoresSafeArea()
        }
        // PopupEnvironment owns keyboard avoidance; this reader measures physical safe areas only.
        .ignoresSafeArea(.keyboard)
        .environment(\.locale, environmentBridge.locale)
        .environment(\.layoutDirection, environmentBridge.layoutDirection)
        .environment(\.dynamicTypeSize, environmentBridge.dynamicTypeSize)
        .popupAnchorRegistrationContext(
            PopupAnchorRegistrationContext(
                sceneSessionID: sceneSessionID,
                popupStackID: popupStack.id,
                sourceCoordinateSpace: .popupView,
                popupCoordinateSpace: .popupView
            )
        )
        .preferredColorScheme(environmentBridge.colorScheme)
    }
}

@MainActor
final class PopupKeyboardObserver: NSObject, ObservableObject {
    @Published private(set) var occlusionHeight: CGFloat = 0
    weak var window: UIWindow?
    weak var containerView: UIView?
    private var keyboardFrameInScreen: CGRect?
    private var isRefreshScheduled = false

    func refreshGeometry() {
        guard !isRefreshScheduled else { return }
        isRefreshScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isRefreshScheduled = false
            self.applyCurrentGeometry()
        }
    }

    private func currentHeight() -> CGFloat {
        guard let window else { return 0 }
        let container = containerView ?? window
        let keyboard: CGRect
        if let keyboardFrameInScreen {
            keyboard = container.convert(keyboardFrameInScreen, from: window.screen.coordinateSpace)
        } else {
            keyboard = container.convert(window.keyboardLayoutGuide.layoutFrame, from: window)
        }
        let bounds = (container as? PopupContainerView)?.popupLayoutBounds ?? container.bounds
        let safeAreaBottom = (container as? PopupContainerView)?.popupLayoutSafeAreaBottom ?? container.safeAreaInsets.bottom
        return PopupKeyboardGeometry.occlusionHeight(container: bounds,
            safeAreaBottom: safeAreaBottom, keyboard: keyboard)
    }

    private func applyCurrentGeometry() {
        let height = currentHeight()
        if height != occlusionHeight { occlusionHeight = height }
    }

    init(notificationCenter: NotificationCenter = .default) {
        super.init()
        notificationCenter.addObserver(
            self,
            selector: #selector(update(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(update(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func update(_ notification: Notification) {
        keyboardFrameInScreen = notification.name == UIResponder.keyboardWillHideNotification
            ? .null : notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
        let height = currentHeight()
        guard height != occlusionHeight else { return }
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0
        let curve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int ?? 0
        let animation: Animation
        switch UIView.AnimationCurve(rawValue: curve) {
        case .easeIn: animation = .easeIn(duration: duration)
        case .easeOut: animation = .easeOut(duration: duration)
        case .linear: animation = .linear(duration: duration)
        default: animation = .easeInOut(duration: duration)
        }
        withAnimation(animation) {
            occlusionHeight = height
        }
    }
}
#endif
