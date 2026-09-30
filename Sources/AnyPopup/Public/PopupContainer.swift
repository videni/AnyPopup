#if canImport(UIKit)
import SwiftUI
import UIKit

/// 将弹窗挂在所属页面内部，复用弹窗栈、布局和触摸穿透规则。
public struct PopupContainer: UIViewControllerRepresentable {
    private let popupStack: PopupStack
    private let defaults: PopupDefaults
    @Environment(\.locale) private var locale
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(popupStack: PopupStack, defaults: PopupDefaults = PopupDefaults()) {
        self.popupStack = popupStack
        self.defaults = defaults
    }

    public func makeUIViewController(context: Context) -> UIViewController {
        PopupContainerController(popupStack: popupStack, defaults: defaults)
    }

    public func updateUIViewController(_ controller: UIViewController, context: Context) {
        guard let controller = controller as? PopupContainerController else { return }
        controller.environmentBridge.update(
            locale: locale, layoutDirection: layoutDirection, colorScheme: colorScheme,
            dynamicTypeSize: dynamicTypeSize, reduceMotion: reduceMotion
        )
    }

    public static func dismantleUIViewController(_ controller: UIViewController, coordinator: ()) {
        (controller as? PopupContainerController)?.disconnect()
    }
}

/// 页面内的弹窗承载视图；布局帧和命中判断都使用此视图的坐标。
public final class PopupContainerView: UIView {
    private static let mountedViews = NSHashTable<PopupContainerView>.weakObjects()
    public let interactionMap: PopupInteractionMap
    fileprivate var windowDidChange: ((UIWindow?) -> Void)?

    fileprivate init(interactionMap: PopupInteractionMap) {
        self.interactionMap = interactionMap
        super.init(frame: .zero)
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            Self.mountedViews.remove(self)
        } else {
            Self.mountedViews.add(self)
        }
        windowDidChange?(window)
    }

    public static func mounted(in scene: UIWindowScene) -> [PopupContainerView] {
        mountedViews.allObjects.filter {
            $0.window?.windowScene === scene && !$0.isHidden && $0.alpha > 0.01
        }
    }

    public override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        PopupWindowRouting.hitTarget(at: point, interactionMap: interactionMap) != .passThrough
    }

    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard PopupWindowRouting.hitTarget(at: point, interactionMap: interactionMap) != .passThrough else {
            return nil
        }
        return super.hitTest(point, with: event)
    }
}

@MainActor
private final class PopupContainerController: UIViewController {
    let environmentBridge = PopupEnvironmentBridge()
    private let popupStack: PopupStack
    private let defaults: PopupDefaults
    private let interactionMap = PopupInteractionMap()
    private let keyboardObserver = PopupKeyboardObserver()
    private let contentController = UIHostingController<AnyView>(rootView: AnyView(EmptyView()))
    private var sceneSessionID: String?

    init(popupStack: PopupStack, defaults: PopupDefaults) {
        self.popupStack = popupStack
        self.defaults = defaults
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func loadView() {
        let container = PopupContainerView(interactionMap: interactionMap)
        container.windowDidChange = { [weak self] window in self?.connect(to: window) }
        view = container
        addChild(contentController)
        contentController.view.backgroundColor = .clear
        contentController.view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(contentController.view)
        NSLayoutConstraint.activate([
            contentController.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            contentController.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            contentController.view.topAnchor.constraint(equalTo: container.topAnchor),
            contentController.view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        contentController.didMove(toParent: self)
    }

    private func connect(to window: UIWindow?) {
        guard let window, let scene = window.windowScene else {
            disconnect()
            return
        }
        let id = scene.session.persistentIdentifier
        guard sceneSessionID != id else { return }
        disconnect()
        sceneSessionID = id
        keyboardObserver.window = window
        PopupStackRegistry.shared.register(popupStack, sceneSessionID: id)
        contentController.rootView = AnyView(PopupSceneRootView(
            popupStack: popupStack, sceneSessionID: id, defaults: defaults,
            interactionMap: interactionMap, environmentBridge: environmentBridge,
            keyboardObserver: keyboardObserver
        ))
    }

    func disconnect() {
        guard let id = sceneSessionID else { return }
        sceneSessionID = nil
        keyboardObserver.window = nil
        PopupStackRegistry.shared.unregister(sceneSessionID: id, popupStackID: popupStack.id)
        contentController.rootView = AnyView(EmptyView())
    }
}
#endif
