import Foundation

public enum PopupSystemPresentationOutcome: Sendable, Equatable {
    case completed
    case sceneDisconnected
    case unavailable
    case busy
}

@MainActor
public protocol PopupSystemPresentationHosting: AnyObject {
    func beginSystemPresentation()
    func endSystemPresentation()
}

@MainActor
public final class SystemPresentationCoordinator {
    public typealias Completion = @MainActor () -> Void
    public typealias Start = @MainActor (@escaping Completion) -> Void

    private struct PendingPresentation {
        let id: UUID
        let continuation: CheckedContinuation<PopupSystemPresentationOutcome, Never>
    }

    private weak var host: (any PopupSystemPresentationHosting)?
    private var pending: PendingPresentation?

    public init(host: (any PopupSystemPresentationHosting)?) {
        self.host = host
    }

    public func perform(_ start: Start) async -> PopupSystemPresentationOutcome {
        guard pending == nil else { return .busy }
        guard let host else { return .unavailable }

        host.beginSystemPresentation()
        let id = UUID()
        return await withCheckedContinuation { continuation in
            pending = PendingPresentation(id: id, continuation: continuation)
            start { [weak self] in
                self?.complete(id: id)
            }
        }
    }

    public func disconnect() {
        finishPending(with: .sceneDisconnected)
        host = nil
    }
}

@MainActor
final class SystemPresentationVisibilityLifetime {
    private var didBecomeVisible = false
    private var didComplete = false
    private let completion: @MainActor () -> Void

    init(completion: @escaping @MainActor () -> Void) {
        self.completion = completion
    }

    func update(isVisible: Bool) {
        guard !didComplete else { return }
        if isVisible {
            didBecomeVisible = true
        } else if didBecomeVisible {
            didComplete = true
            completion()
        }
    }
}

private extension SystemPresentationCoordinator {
    func complete(id: UUID) {
        guard pending?.id == id else { return }
        finishPending(with: .completed)
    }

    func finishPending(with outcome: PopupSystemPresentationOutcome) {
        guard let pending else { return }
        self.pending = nil
        host?.endSystemPresentation()
        pending.continuation.resume(returning: outcome)
    }
}

#if canImport(UIKit)
import UIKit

@MainActor
final class PopupUIKitSystemPresentationHost: PopupSystemPresentationHosting {
    private weak var windowScene: UIWindowScene?
    private var presentationWindow: UIWindow?

    private(set) var presenter: UIViewController?

    init(windowScene: UIWindowScene) {
        self.windowScene = windowScene
    }

    func beginSystemPresentation() {
        guard let windowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.alert.rawValue + 1)
        window.backgroundColor = .clear

        let presenter = UIViewController()
        presenter.view.backgroundColor = .clear
        window.rootViewController = presenter
        window.makeKeyAndVisible()

        self.presenter = presenter
        presentationWindow = window
    }

    func endSystemPresentation() {
        presentationWindow?.isHidden = true
        presentationWindow?.rootViewController = nil
        presentationWindow = nil
        presenter = nil
    }
}

@MainActor
final class PopupSystemPresentationObserverView: UIView {
    private let lifetime: SystemPresentationVisibilityLifetime

    init(completion: @escaping @MainActor () -> Void) {
        lifetime = SystemPresentationVisibilityLifetime(completion: completion)
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        lifetime.update(isVisible: window != nil)
    }
}
#endif
