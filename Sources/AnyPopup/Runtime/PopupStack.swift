import Combine

@MainActor
public struct PopupMutation {
    public let inserted: AnyPopup?
    public let removed: [AnyPopup]
    public let focused: AnyPopup?

    static let none = Self(inserted: nil, removed: [], focused: nil)
}

@MainActor
public final class PopupStack: ObservableObject {
    public let id: PopupStackID
    @Published public private(set) var popups: [AnyPopup]

    public init(id: PopupStackID) {
        self.id = id
        popups = []
    }

    @discardableResult
    public func insert(_ popup: AnyPopup) -> PopupMutation {
        guard !popups.contains(where: { $0.uniquenessKey == popup.uniquenessKey }) else {
            return .none
        }

        popups.append(popup)
        popup.focusAction()
        return PopupMutation(inserted: popup, removed: [], focused: popup)
    }

    @discardableResult
    public func removeLast() -> PopupMutation {
        guard let last = popups.last else { return .none }
        return removePopupAndAbove(last.id)
    }

    @discardableResult
    public func removePopupAndAbove(_ id: PopupID) -> PopupMutation {
        guard let index = popups.firstIndex(where: { $0.id == id }) else { return .none }
        return remove(indices: Array(index..<popups.endIndex))
    }

    @discardableResult
    public func removeAll(excluding customIDs: Set<String> = []) -> PopupMutation {
        let indices = popups.indices.filter { index in
            guard let customID = popups[index].customID else { return true }
            return !customIDs.contains(customID)
        }
        return remove(indices: indices)
    }

    @discardableResult
    public func removePopupAndAbove(customID: String) -> PopupMutation {
        guard let popup = popups.last(where: { $0.customID == customID }) else { return .none }
        return removePopupAndAbove(popup.id)
    }

    @discardableResult
    public func removePopupAndAbove(popupTypeName: String) -> PopupMutation {
        guard let popup = popups.last(where: { $0.popupTypeName == popupTypeName }) else { return .none }
        return removePopupAndAbove(popup.id)
    }
}

private extension PopupStack {
    func remove(indices: [Int]) -> PopupMutation {
        guard !indices.isEmpty else { return .none }

        let oldTopID = popups.last?.id
        let removed = indices.map { popups[$0] }
        for index in indices.reversed() {
            popups.remove(at: index)
        }
        for popup in removed.reversed() {
            popup.dismissAction()
        }

        let newTop = popups.last
        let focused: AnyPopup?
        if newTop?.id != oldTopID {
            newTop?.focusAction()
            focused = newTop
        } else {
            focused = nil
        }
        return PopupMutation(inserted: nil, removed: removed, focused: focused)
    }
}
