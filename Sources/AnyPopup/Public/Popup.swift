import SwiftUI

public protocol PopupConfiguration: Sendable {}

public protocol Popup: View, Sendable {
    associatedtype Config: PopupConfiguration

    var popupConfig: Config { get }

    func onFocus()
    func onDismiss()
}

public extension Popup {
    func onFocus() {}
    func onDismiss() {}
}
