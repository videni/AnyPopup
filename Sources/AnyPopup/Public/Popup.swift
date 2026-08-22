import SwiftUI

public protocol PopupConfiguration: Sendable {}

public protocol Popup: View, Sendable {
    associatedtype Config: PopupConfiguration

    var popupConfig: Config { get }

    @MainActor func onFocus()
    @MainActor func onDismiss()
}

public extension Popup {
    @MainActor func onFocus() {}
    @MainActor func onDismiss() {}
}
