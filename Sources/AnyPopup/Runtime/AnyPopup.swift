import Foundation
import SwiftUI

public struct PopupID: Sendable, Hashable {
    public let rawValue: UUID

    public init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

public enum PopupAnchorSource: Sendable, Equatable {
    case tracked(String)
    case frame(CGRect)
}

public enum AnyPopupConfiguration: Sendable {
    case container(ContainerPopupConfig)
    case anchored(AnchoredPopupConfig)
}

public enum PopupUniquenessKey: Sendable, Hashable {
    case type(String)
    case customID(String)
}

@MainActor
public struct AnyPopup: Identifiable {
    public let id: PopupID
    public let popupTypeName: String
    public let customID: String?
    public let configuration: AnyPopupConfiguration
    public let anchorSource: PopupAnchorSource?
    public let body: AnyView
    public let dismissAfter: TimeInterval?
    public let dismissKeyboardOnDismissal: Bool

    let focusAction: @MainActor () -> Void
    let dismissAction: @MainActor () -> Void

    public var uniquenessKey: PopupUniquenessKey {
        if let customID {
            return .customID(customID)
        }
        return .type(popupTypeName)
    }
}

extension AnyPopup {
    init<P: Popup>(_ popup: P) where P.Config == ContainerPopupConfig {
        self.init(
            popup: popup,
            configuration: .container(popup.popupConfig),
            anchorSource: nil,
            customIDOverride: nil,
            defaultCustomID: nil
        )
    }

    init<P: Popup>(
        _ popup: P,
        anchorSource: PopupAnchorSource,
        customIDOverride: String? = nil,
        defaultCustomID: String? = nil
    ) where P.Config == AnchoredPopupConfig {
        self.init(
            popup: popup,
            configuration: .anchored(popup.popupConfig),
            anchorSource: anchorSource,
            customIDOverride: customIDOverride,
            defaultCustomID: defaultCustomID
        )
    }

    private init<P: Popup>(
        popup: P,
        configuration: AnyPopupConfiguration,
        anchorSource: PopupAnchorSource?,
        customIDOverride: String?,
        defaultCustomID: String?
    ) {
        let metadata = (popup as? any PopupCommandMetadataProviding)?.popupCommandMetadata
        var erasedBody = AnyView(popup)
        for application in metadata?.environmentObjects ?? [] {
            erasedBody = application.apply(to: erasedBody)
        }

        id = PopupID()
        popupTypeName = metadata?.originalPopupTypeName ?? String(reflecting: P.self)
        customID = customIDOverride ?? metadata?.customID ?? defaultCustomID
        self.configuration = configuration
        self.anchorSource = anchorSource
        body = erasedBody
        dismissAfter = metadata?.dismissAfter
        dismissKeyboardOnDismissal = metadata?.dismissKeyboardOnDismissal ?? true
        focusAction = popup.onFocus
        dismissAction = popup.onDismiss
    }
}
