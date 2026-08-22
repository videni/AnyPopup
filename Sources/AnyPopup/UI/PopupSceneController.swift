#if canImport(UIKit)
import Combine
import SwiftUI
import UIKit

public typealias PopupHostingController = UIHostingController<AnyView>

@MainActor
public final class PopupSceneController {
    public let sceneSessionID: String
    public let popupStackID: PopupStackID
    public let popupStack: PopupStack
    public let interactionMap: PopupInteractionMap
    public let environmentBridge: PopupEnvironmentBridge
    public let window: PopupWindow
    public let systemPresentationCoordinator: SystemPresentationCoordinator

    private weak var windowScene: UIWindowScene?
    private weak var previousKeyWindow: UIWindow?
    private let keyboardObserver: PopupKeyboardObserver
    private let systemPresentationHost: PopupUIKitSystemPresentationHost
    private var defaults: PopupDefaults
    private var cancellables: Set<AnyCancellable> = []
    private var hasStarted = false
    private var isSystemPresentationActive = false

    public init(
        windowScene: UIWindowScene,
        popupStackID: PopupStackID = .shared,
        defaults: PopupDefaults = PopupDefaults(),
        environmentBridge: PopupEnvironmentBridge = PopupEnvironmentBridge()
    ) {
        sceneSessionID = windowScene.session.persistentIdentifier
        self.popupStackID = popupStackID
        self.defaults = defaults
        self.environmentBridge = environmentBridge
        self.windowScene = windowScene

        let interactionMap = PopupInteractionMap()
        self.interactionMap = interactionMap
        popupStack = PopupStack(id: popupStackID)
        window = PopupWindow(windowScene: windowScene, interactionMap: interactionMap)
        keyboardObserver = PopupKeyboardObserver()
        let presentationHost = PopupUIKitSystemPresentationHost(windowScene: windowScene)
        systemPresentationHost = presentationHost
        systemPresentationCoordinator = SystemPresentationCoordinator(host: presentationHost)
    }

    public func start() {
        guard !hasStarted else { return }
        hasStarted = true
        PopupStackRegistry.shared.register(popupStack, sceneSessionID: sceneSessionID)
        installRootView()
        keyboardObserver.window = window
        window.isHidden = false

        Publishers.CombineLatest(
            popupStack.$popups,
            popupStack.dismissalCoordinator.$snapshots
        )
        .sink { [weak self] popups, snapshots in
            self?.updateKeyWindow(hasVisualContent: !popups.isEmpty || !snapshots.isEmpty)
        }
        .store(in: &cancellables)
    }

    public func update(defaults: PopupDefaults) {
        self.defaults = defaults
        guard hasStarted else { return }
        installRootView()
    }

    public func updateEnvironment(
        locale: Locale,
        layoutDirection: LayoutDirection,
        colorScheme: ColorScheme?,
        dynamicTypeSize: DynamicTypeSize,
        reduceMotion: Bool
    ) {
        environmentBridge.update(
            locale: locale,
            layoutDirection: layoutDirection,
            colorScheme: colorScheme,
            dynamicTypeSize: dynamicTypeSize,
            reduceMotion: reduceMotion
        )
    }

    public func anchorRegistrationContext(
        sourceWindow: UIWindow
    ) -> PopupAnchorRegistrationContext? {
        guard let windowScene,
            sourceWindow.windowScene === windowScene else { return nil }
        return PopupAnchorRegistrationContext(
            sceneSessionID: sceneSessionID,
            popupStackID: popupStackID,
            sourceCoordinateSpace: coordinateSpace(
                of: sourceWindow,
                in: windowScene
            ),
            popupCoordinateSpace: coordinateSpace(
                of: window,
                in: windowScene
            )
        )
    }

    public func performSystemPresentation(
        _ start: @escaping @MainActor (
            UIViewController,
            @escaping SystemPresentationCoordinator.Completion
        ) -> Void
    ) async -> PopupSystemPresentationOutcome {
        isSystemPresentationActive = true
        let outcome = await systemPresentationCoordinator.perform { [weak self] completion in
            guard let presenter = self?.systemPresentationHost.presenter else {
                completion()
                return
            }
            start(presenter, completion)
        }
        isSystemPresentationActive = false
        updateKeyWindow(
            hasVisualContent: !popupStack.popups.isEmpty
                || !popupStack.dismissalCoordinator.snapshots.isEmpty
        )
        return outcome
    }

    public func disconnect() {
        guard hasStarted else { return }
        hasStarted = false
        systemPresentationCoordinator.disconnect()
        PopupStackRegistry.shared.unregister(
            sceneSessionID: sceneSessionID,
            popupStackID: popupStackID
        )
        AnchorRegistry.shared.removeAll(sceneSessionID: sceneSessionID)
        cancellables.removeAll()
        restorePreviousKeyWindow()
        window.isHidden = true
        window.rootViewController = nil
    }
}

public enum PopupSystemPresenter {
    public static func perform(
        popupStackID: PopupStackID = .shared,
        _ start: @escaping @MainActor (
            UIViewController,
            @escaping SystemPresentationCoordinator.Completion
        ) -> Void
    ) async -> PopupSystemPresentationOutcome {
        guard let controller = await PopupSceneControllerRegistry.shared.resolve(
            popupStackID: popupStackID
        ) else { return .unavailable }
        return await controller.performSystemPresentation(start)
    }

    public static func present(
        _ viewController: UIViewController,
        popupStackID: PopupStackID = .shared,
        animated: Bool = true
    ) async -> PopupSystemPresentationOutcome {
        await perform(popupStackID: popupStackID) { presenter, completion in
            guard presenter.presentedViewController == nil else {
                completion()
                return
            }

            let observer = PopupSystemPresentationObserverView(completion: completion)
            viewController.view.addSubview(observer)
            presenter.present(viewController, animated: animated)
        }
    }
}

open class AnyPopupSceneDelegate: NSObject, UIWindowSceneDelegate {
    open var window: UIWindow?
    open var configBuilder: (PopupDefaults) -> PopupDefaults = { $0 }
    open var popupStackID: PopupStackID = .shared
    open var keyboardManagerInstaller: (@MainActor (UIViewController.Type) -> Void)?
    public private(set) var popupSceneController: PopupSceneController?

    open func sceneStoppedBeingFirstResponder() {}

    open func makeSceneKey() {
        window?.makeKey()
    }

    open func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let defaults = configBuilder(PopupDefaults())
        let controller = PopupSceneControllerRegistry.shared.controller(
            windowScene: windowScene,
            popupStackID: popupStackID,
            defaults: defaults
        )
        controller.update(defaults: defaults)
        controller.start()
        if let keyboardManagerInstaller {
            KeyboardManagerIntegration.shared.installOnce(
                sceneSessionID: session.persistentIdentifier
            ) {
                keyboardManagerInstaller(PopupHostingController.self)
            }
        }
        popupSceneController = controller
        window = controller.window
    }

    open func sceneDidBecomeActive(_ scene: UIScene) {
        guard let windowScene = scene as? UIWindowScene else { return }
        PopupSceneControllerRegistry.shared.setActiveSceneSessionID(
            windowScene.session.persistentIdentifier
        )
        PopupStackRegistry.shared.setActiveSceneSessionID(
            windowScene.session.persistentIdentifier
        )
    }

    open func sceneWillResignActive(_ scene: UIScene) {
        guard let windowScene = scene as? UIWindowScene else { return }
        PopupSceneControllerRegistry.shared.clearActiveSceneSessionID(
            windowScene.session.persistentIdentifier
        )
        PopupStackRegistry.shared.setActiveSceneSessionID(nil)
    }

    open func sceneDidDisconnect(_ scene: UIScene) {
        popupSceneController?.disconnect()
        if let windowScene = scene as? UIWindowScene {
            PopupSceneControllerRegistry.shared.remove(
                sceneSessionID: windowScene.session.persistentIdentifier,
                popupStackID: popupStackID
            )
        }
        popupSceneController = nil
        window = nil
    }
}

@MainActor
final class PopupSceneControllerRegistry {
    static let shared = PopupSceneControllerRegistry()

    struct Key: Hashable {
        let sceneSessionID: String
        let popupStackID: PopupStackID
    }

    private var controllers: [Key: PopupSceneController] = [:]
    private var activeSceneSessionID: String?

    func controller(
        windowScene: UIWindowScene,
        popupStackID: PopupStackID,
        defaults: PopupDefaults
    ) -> PopupSceneController {
        let key = Key(
            sceneSessionID: windowScene.session.persistentIdentifier,
            popupStackID: popupStackID
        )
        if let existing = controllers[key] {
            return existing
        }
        let controller = PopupSceneController(
            windowScene: windowScene,
            popupStackID: popupStackID,
            defaults: defaults
        )
        controllers[key] = controller
        return controller
    }

    func resolve(popupStackID: PopupStackID) -> PopupSceneController? {
        if let activeSceneSessionID {
            return controllers[Key(
                sceneSessionID: activeSceneSessionID,
                popupStackID: popupStackID
            )]
        }
        let matches = controllers.compactMap { key, controller in
            key.popupStackID == popupStackID ? controller : nil
        }
        return matches.count == 1 ? matches[0] : nil
    }

    func setActiveSceneSessionID(_ sceneSessionID: String) {
        activeSceneSessionID = sceneSessionID
    }

    func clearActiveSceneSessionID(_ sceneSessionID: String) {
        guard activeSceneSessionID == sceneSessionID else { return }
        activeSceneSessionID = nil
    }

    func remove(sceneSessionID: String, popupStackID: PopupStackID) {
        controllers.removeValue(forKey: Key(
            sceneSessionID: sceneSessionID,
            popupStackID: popupStackID
        ))
        clearActiveSceneSessionID(sceneSessionID)
    }
}

private extension PopupSceneController {
    func installRootView() {
        let root = PopupSceneRootView(
            popupStack: popupStack,
            sceneSessionID: sceneSessionID,
            defaults: defaults,
            interactionMap: interactionMap,
            environmentBridge: environmentBridge,
            keyboardObserver: keyboardObserver
        )
        let hostingController = PopupHostingController(rootView: AnyView(root))
        hostingController.view.backgroundColor = .clear
        window.rootViewController = hostingController
    }

    func updateKeyWindow(hasVisualContent: Bool) {
        guard let windowScene else { return }
        guard !isSystemPresentationActive else { return }
        if hasVisualContent {
            if !window.isKeyWindow {
                previousKeyWindow = windowScene.windows.first(where: {
                    $0 !== window && $0.isKeyWindow
                })
                window.makeKey()
            }
        } else {
            restorePreviousKeyWindow()
        }
    }

    func restorePreviousKeyWindow() {
        guard window.isKeyWindow else {
            previousKeyWindow = nil
            return
        }
        previousKeyWindow?.makeKey()
        previousKeyWindow = nil
    }

    func coordinateSpace(
        of window: UIWindow,
        in windowScene: UIWindowScene
    ) -> PopupCoordinateSpace {
        let source = window.coordinateSpace
        let destination = windowScene.effectiveGeometry.coordinateSpace
        let origin = source.convert(CGPoint.zero, to: destination)
        let unitX = source.convert(CGPoint(x: 1, y: 0), to: destination)
        let unitY = source.convert(CGPoint(x: 0, y: 1), to: destination)
        return PopupCoordinateSpace(
            transformToScene: CGAffineTransform(
                a: unitX.x - origin.x,
                b: unitX.y - origin.y,
                c: unitY.x - origin.x,
                d: unitY.y - origin.y,
                tx: origin.x,
                ty: origin.y
            )
        )
    }
}
#endif
