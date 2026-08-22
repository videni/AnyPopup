import Foundation

@MainActor
protocol PopupDismissScheduling: AnyObject {
    func schedule(
        popupID: PopupID,
        after seconds: TimeInterval,
        action: @escaping @MainActor () -> Void
    )
    func cancel(popupID: PopupID)
}

@MainActor
final class DefaultPopupDismissScheduler: PopupDismissScheduling {
    private var tasks: [PopupID: Task<Void, Never>] = [:]

    func schedule(
        popupID: PopupID,
        after seconds: TimeInterval,
        action: @escaping @MainActor () -> Void
    ) {
        cancel(popupID: popupID)
        guard seconds.isFinite, seconds >= 0 else { return }
        tasks[popupID] = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(seconds))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            action()
            self?.tasks[popupID] = nil
        }
    }

    func cancel(popupID: PopupID) {
        tasks.removeValue(forKey: popupID)?.cancel()
    }
}

public enum PopupStackResolutionError: Sendable, Equatable {
    case missing(PopupStackID)
    case ambiguous(PopupStackID)
}

@MainActor
public final class PopupStackRegistry {
    public static let shared = PopupStackRegistry()

    public private(set) var lastResolutionError: PopupStackResolutionError?

    struct Key: Hashable {
        let sceneSessionID: String
        let popupStackID: PopupStackID
    }

    private var stacks: [Key: PopupStack] = [:]
    private var activeSceneSessionID: String?
    private let dismissScheduler: any PopupDismissScheduling

    init(dismissScheduler: any PopupDismissScheduling = DefaultPopupDismissScheduler()) {
        self.dismissScheduler = dismissScheduler
    }

    public func register(_ stack: PopupStack, sceneSessionID: String) {
        let key = Key(sceneSessionID: sceneSessionID, popupStackID: stack.id)
        if let replaced = stacks.updateValue(stack, forKey: key) {
            _ = applyRemoval(replaced.removeAll())
            replaced.dismissalCoordinator.cancelAll()
        }
        lastResolutionError = nil
    }

    public func unregister(sceneSessionID: String, popupStackID: PopupStackID) {
        let removed = stacks.removeValue(forKey: Key(
            sceneSessionID: sceneSessionID,
            popupStackID: popupStackID
        ))
        if let removed {
            _ = applyRemoval(removed.removeAll())
            removed.dismissalCoordinator.cancelAll()
        }
        if activeSceneSessionID == sceneSessionID,
            !stacks.keys.contains(where: { $0.sceneSessionID == sceneSessionID }) {
            activeSceneSessionID = nil
        }
    }

    public func setActiveSceneSessionID(_ sceneSessionID: String?) {
        activeSceneSessionID = sceneSessionID
    }

    public func stack(
        sceneSessionID: String,
        popupStackID: PopupStackID = .shared
    ) -> PopupStack? {
        stacks[Key(sceneSessionID: sceneSessionID, popupStackID: popupStackID)]
    }

    func resolvedSceneSessionID(popupStackID: PopupStackID) -> String? {
        resolve(popupStackID)?.key.sceneSessionID
    }

    @discardableResult
    func insert(
        _ popup: AnyPopup,
        sceneSessionID: String,
        popupStackID: PopupStackID
    ) -> PopupMutation {
        guard let stack = stack(
            sceneSessionID: sceneSessionID,
            popupStackID: popupStackID
        ) else {
            lastResolutionError = .missing(popupStackID)
            return .none
        }
        lastResolutionError = nil
        return applyInsert(popup, to: stack, key: Key(
            sceneSessionID: sceneSessionID,
            popupStackID: popupStackID
        ))
    }

    @discardableResult
    func removePopupAndAbove(
        _ popupID: PopupID,
        sceneSessionID: String,
        popupStackID: PopupStackID
    ) -> PopupMutation {
        guard let stack = stack(
            sceneSessionID: sceneSessionID,
            popupStackID: popupStackID
        ) else { return .none }
        return applyRemoval(stack.removePopupAndAbove(popupID))
    }
}

extension PopupStackRegistry {
    @discardableResult
    func insert(_ popup: AnyPopup, popupStackID: PopupStackID) -> PopupMutation {
        guard let entry = resolve(popupStackID) else { return .none }
        return applyInsert(popup, to: entry.stack, key: entry.key)
    }

    @discardableResult
    func removeLast(popupStackID: PopupStackID) -> PopupMutation {
        guard let stack = resolve(popupStackID)?.stack else { return .none }
        return applyRemoval(stack.removeLast())
    }

    @discardableResult
    func removePopupAndAbove(customID: String, popupStackID: PopupStackID) -> PopupMutation {
        guard let stack = resolve(popupStackID)?.stack else { return .none }
        return applyRemoval(stack.removePopupAndAbove(customID: customID))
    }

    @discardableResult
    func removePopupAndAbove(popupTypeName: String, popupStackID: PopupStackID) -> PopupMutation {
        guard let stack = resolve(popupStackID)?.stack else { return .none }
        return applyRemoval(stack.removePopupAndAbove(popupTypeName: popupTypeName))
    }

    @discardableResult
    func removeAll(
        excluding customIDs: Set<String> = [],
        popupStackID: PopupStackID
    ) -> PopupMutation {
        guard let stack = resolve(popupStackID)?.stack else { return .none }
        return applyRemoval(stack.removeAll(excluding: customIDs))
    }
}

private extension PopupStackRegistry {
    struct Entry {
        let key: Key
        let stack: PopupStack
    }

    func resolve(_ popupStackID: PopupStackID) -> Entry? {
        if let activeSceneSessionID {
            let key = Key(
                sceneSessionID: activeSceneSessionID,
                popupStackID: popupStackID
            )
            if let stack = stacks[key] {
                lastResolutionError = nil
                return Entry(key: key, stack: stack)
            }
            lastResolutionError = .missing(popupStackID)
            return nil
        }

        let matches = stacks.compactMap { key, stack -> Entry? in
            key.popupStackID == popupStackID ? Entry(key: key, stack: stack) : nil
        }
        guard matches.count == 1 else {
            lastResolutionError = matches.isEmpty ? .missing(popupStackID) : .ambiguous(popupStackID)
            return nil
        }
        lastResolutionError = nil
        return matches[0]
    }

    func applyInsert(_ popup: AnyPopup, to stack: PopupStack, key: Key) -> PopupMutation {
        let mutation = stack.insert(popup)
        guard mutation.inserted != nil, let seconds = popup.dismissAfter else { return mutation }
        dismissScheduler.schedule(popupID: popup.id, after: seconds) { [weak self] in
            _ = self?.removePopupAndAbove(
                popup.id,
                sceneSessionID: key.sceneSessionID,
                popupStackID: key.popupStackID
            )
        }
        return mutation
    }

    func applyRemoval(_ mutation: PopupMutation) -> PopupMutation {
        for popup in mutation.removed {
            dismissScheduler.cancel(popupID: popup.id)
        }
        return mutation
    }
}
