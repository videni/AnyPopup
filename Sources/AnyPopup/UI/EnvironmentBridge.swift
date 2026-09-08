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
            let fallbackContainerSize = PopupSceneGeometry.fullContainerSize(
                contentSize: proxy.size,
                safeArea: proxy.safeAreaInsets
            )
            let viewport = keyboardObserver.viewport(
                fallbackContainerSize: fallbackContainerSize,
                fallbackSafeArea: proxy.safeAreaInsets
            )
            PopupView(
                popupStack: popupStack,
                sceneSessionID: sceneSessionID,
                environment: viewport.environment(reduceMotion: environmentBridge.reduceMotion),
                defaults: defaults,
                interactionMap: interactionMap
            )
            .environment(\.popupContainerSize, viewport.containerSize)
            .ignoresSafeArea()
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
    private let dismissalWaiters = PopupKeyboardDismissalWaiters()
    weak var window: UIWindow? {
        didSet {
            objectWillChange.send()
        }
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
        notificationCenter.addObserver(
            self,
            selector: #selector(update(_:)),
            name: UIResponder.keyboardDidHideNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func viewport(
        fallbackContainerSize: CGSize,
        fallbackSafeArea: EdgeInsets
    ) -> PopupViewport {
        guard let window else {
            return PopupViewport(
                containerSize: fallbackContainerSize,
                systemSafeArea: fallbackSafeArea,
                keyboardOcclusionHeight: occlusionHeight
            )
        }
        return PopupViewport(
            containerSize: window.bounds.size,
            systemSafeArea: EdgeInsets(
                top: window.safeAreaInsets.top,
                leading: window.safeAreaInsets.left,
                bottom: window.safeAreaInsets.bottom,
                trailing: window.safeAreaInsets.right
            ),
            keyboardOcclusionHeight: occlusionHeight
        )
    }

    @objc private func update(_ notification: Notification) {
        if notification.name == UIResponder.keyboardDidHideNotification {
            occlusionHeight = 0
            dismissalWaiters.resumeAll()
            return
        }
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

    func cancelPendingKeyboardDismissal() {
        dismissalWaiters.resumeAll()
    }
}

extension PopupKeyboardObserver: PopupKeyboardDismissing {
    func dismissAndWait() async {
        if dismissalWaiters.isWaiting {
            await dismissalWaiters.wait { true }
            return
        }
        guard occlusionHeight > 0, let window else { return }
        await dismissalWaiters.wait {
            window.endEditing(true)
        }
    }
}
#endif
