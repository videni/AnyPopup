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
        self.locale = locale
        self.layoutDirection = layoutDirection
        self.colorScheme = colorScheme
        self.dynamicTypeSize = dynamicTypeSize
        self.reduceMotion = reduceMotion
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
            PopupView(
                popupStack: popupStack,
                sceneSessionID: sceneSessionID,
                environment: environmentBridge.popupEnvironment(
                    containerSize: proxy.size,
                    safeArea: proxy.safeAreaInsets,
                    keyboardOcclusionHeight: keyboardObserver.occlusionHeight
                ),
                defaults: defaults,
                interactionMap: interactionMap
            )
        }
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
        guard notification.name != UIResponder.keyboardWillHideNotification,
            let window,
            let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            occlusionHeight = 0
            return
        }
        let converted = window.convert(frame, from: nil)
        let rawOcclusion = max(0, window.bounds.maxY - converted.minY)
        occlusionHeight = max(0, rawOcclusion - window.safeAreaInsets.bottom)
    }
}
#endif
