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
    private weak var popupWindow: UIWindow?
    private weak var previousKeyWindow: UIWindow?

    init(windowScene: UIWindowScene, popupWindow: UIWindow) {
        self.windowScene = windowScene
        self.popupWindow = popupWindow
    }

    func beginSystemPresentation() {
        guard let popupWindow, let windowScene else { return }
        previousKeyWindow = windowScene.windows.first(where: { $0.isKeyWindow })
        popupWindow.makeKey()
    }

    func endSystemPresentation() {
        previousKeyWindow?.makeKey()
        previousKeyWindow = nil
    }
}
#endif
