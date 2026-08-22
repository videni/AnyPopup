import Foundation
import SwiftUI

struct PopupEnvironmentObjectApplication: @unchecked Sendable {
    // ObservableObject need not be Sendable. Stored application is consumed only by
    // MainActor AnyPopup initialization; PopupCommand.body never reads it.
    private let application: (AnyView) -> AnyView

    init<Object: ObservableObject>(_ object: Object) {
        application = { body in AnyView(body.environmentObject(object)) }
    }

    @MainActor func apply(to body: AnyView) -> AnyView {
        application(body)
    }
}

struct PopupCommandMetadata: @unchecked Sendable {
    let originalPopupTypeName: String
    var customID: String?
    var environmentObjects: [PopupEnvironmentObjectApplication] = []
    var dismissAfter: TimeInterval?
    var dismissKeyboardOnDismissal = true
}

protocol PopupCommandMetadataProviding {
    var popupCommandMetadata: PopupCommandMetadata { get }
}

public struct PopupCommand<Content: Popup>: Popup, PopupCommandMetadataProviding {
    let content: Content
    var popupCommandMetadata: PopupCommandMetadata

    init(content: Content) {
        self.content = content
        popupCommandMetadata = PopupCommandMetadata(
            originalPopupTypeName: String(reflecting: Content.self)
        )
    }

    public var popupConfig: Content.Config {
        content.popupConfig
    }

    public var body: some View {
        content
    }

    @MainActor public func onFocus() {
        content.onFocus()
    }

    @MainActor public func onDismiss() {
        content.onDismiss()
    }
}

public extension Popup {
    func setCustomID(_ id: String) -> PopupCommand<Self> {
        PopupCommand(content: self).setCustomID(id)
    }

    func setEnvironmentObject<Object: ObservableObject>(_ object: Object) -> PopupCommand<Self> {
        PopupCommand(content: self).setEnvironmentObject(object)
    }

    func dismissAfter(_ seconds: TimeInterval) -> PopupCommand<Self> {
        PopupCommand(content: self).dismissAfter(seconds)
    }

    func dismissKeyboardOnDismissal(_ shouldDismiss: Bool) -> PopupCommand<Self> {
        PopupCommand(content: self).dismissKeyboardOnDismissal(shouldDismiss)
    }
}

public extension PopupCommand {
    func setCustomID(_ id: String) -> Self {
        updated { $0.customID = id }
    }

    func setEnvironmentObject<Object: ObservableObject>(_ object: Object) -> Self {
        updated { $0.environmentObjects.append(PopupEnvironmentObjectApplication(object)) }
    }

    func dismissAfter(_ seconds: TimeInterval) -> Self {
        updated { $0.dismissAfter = seconds }
    }

    func dismissKeyboardOnDismissal(_ shouldDismiss: Bool) -> Self {
        updated { $0.dismissKeyboardOnDismissal = shouldDismiss }
    }

    private func updated(_ update: (inout PopupCommandMetadata) -> Void) -> Self {
        var copy = self
        update(&copy.popupCommandMetadata)
        return copy
    }
}

public extension Popup where Config == ContainerPopupConfig {
    @MainActor
    func present(popupStackID: PopupStackID = .shared) async {
        _ = PopupStackRegistry.shared.insert(AnyPopup(self), popupStackID: popupStackID)
    }
}

public extension Popup where Config == AnchoredPopupConfig {
    @MainActor
    func present(
        anchoredTo anchorID: String,
        customID: String? = nil,
        popupStackID: PopupStackID = .shared
    ) async {
        let popup = AnyPopup(
            self,
            anchorSource: .tracked(anchorID),
            customIDOverride: customID,
            defaultCustomID: anchorID
        )
        _ = PopupStackRegistry.shared.insert(popup, popupStackID: popupStackID)
    }

    @MainActor
    func present(
        anchoredTo frame: CGRect,
        customID: String? = nil,
        popupStackID: PopupStackID = .shared
    ) async {
        let popup = AnyPopup(
            self,
            anchorSource: .frame(frame),
            customIDOverride: customID
        )
        _ = PopupStackRegistry.shared.insert(popup, popupStackID: popupStackID)
    }
}

@MainActor
public func dismissLastPopup(popupStackID: PopupStackID = .shared) async {
    PopupCommands.dismissLast(popupStackID: popupStackID)
}

@MainActor
public func dismissPopup(_ id: String, popupStackID: PopupStackID = .shared) async {
    PopupCommands.dismiss(customID: id, popupStackID: popupStackID)
}

@MainActor
public func dismissPopup<P: Popup>(_ type: P.Type, popupStackID: PopupStackID = .shared) async {
    PopupCommands.dismiss(popupTypeName: String(reflecting: type), popupStackID: popupStackID)
}

@MainActor
public func dismissAllPopups(popupStackID: PopupStackID = .shared) async {
    PopupCommands.dismissAll(popupStackID: popupStackID)
}

@MainActor
public func dismissAllPopups(
    excluding ids: [String],
    popupStackID: PopupStackID = .shared
) async {
    PopupCommands.dismissAll(excluding: Set(ids), popupStackID: popupStackID)
}

public extension PopupStack {
    @MainActor static func dismissLastPopup(popupStackID: PopupStackID = .shared) async {
        PopupCommands.dismissLast(popupStackID: popupStackID)
    }

    @MainActor static func dismissPopup(_ id: String, popupStackID: PopupStackID = .shared) async {
        PopupCommands.dismiss(customID: id, popupStackID: popupStackID)
    }

    @MainActor static func dismissPopup<P: Popup>(
        _ type: P.Type,
        popupStackID: PopupStackID = .shared
    ) async {
        PopupCommands.dismiss(popupTypeName: String(reflecting: type), popupStackID: popupStackID)
    }

    @MainActor static func dismissAllPopups(popupStackID: PopupStackID = .shared) async {
        PopupCommands.dismissAll(popupStackID: popupStackID)
    }

    @MainActor static func dismissAllPopups(
        excluding ids: [String],
        popupStackID: PopupStackID = .shared
    ) async {
        PopupCommands.dismissAll(excluding: Set(ids), popupStackID: popupStackID)
    }
}

@MainActor
private enum PopupCommands {
    static func dismissLast(popupStackID: PopupStackID) {
        _ = PopupStackRegistry.shared.removeLast(popupStackID: popupStackID)
    }

    static func dismiss(customID: String, popupStackID: PopupStackID) {
        _ = PopupStackRegistry.shared.removePopupAndAbove(
            customID: customID,
            popupStackID: popupStackID
        )
    }

    static func dismiss(popupTypeName: String, popupStackID: PopupStackID) {
        _ = PopupStackRegistry.shared.removePopupAndAbove(
            popupTypeName: popupTypeName,
            popupStackID: popupStackID
        )
    }

    static func dismissAll(
        excluding customIDs: Set<String> = [],
        popupStackID: PopupStackID
    ) {
        _ = PopupStackRegistry.shared.removeAll(
            excluding: customIDs,
            popupStackID: popupStackID
        )
    }
}
