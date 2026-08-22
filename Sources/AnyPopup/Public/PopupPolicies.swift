import SwiftUI

enum PopupConfigurationField: Sendable, Hashable {
    case size
    case padding
    case corners
    case background
    case backdrop
    case insertionTransition
    case removalTransition
    case outsideInteraction
    case keyboardAvoidance
    case stackAppearance
    case safeArea
    case drag
    case detents
    case sourceAnchor
    case popupAnchor
    case offset
    case screenAvoidance
}

func inheritPopupDefault<Configuration, Value>(
    _ field: PopupConfigurationField,
    explicitFields: Set<PopupConfigurationField>,
    defaultExplicitFields: Set<PopupConfigurationField>,
    defaults: Configuration,
    result: inout Configuration,
    at keyPath: WritableKeyPath<Configuration, Value>
) {
    guard !explicitFields.contains(field), defaultExplicitFields.contains(field) else { return }
    result[keyPath: keyPath] = defaults[keyPath: keyPath]
}

public enum PopupDimension: Sendable, Equatable {
    case content
    case fixed(CGFloat)
    case fraction(CGFloat)
    case fill
}

public enum PopupSizePolicy: Sendable, Equatable {
    case content
    case dimensions(width: PopupDimension, height: PopupDimension)
}

public struct PopupCorners: Sendable, Equatable {
    public let radius: CGFloat
    public let attachedEdges: Edge.Set

    public static func all(radius: CGFloat) -> Self {
        Self(radius: radius, attachedEdges: [])
    }

    public static func attached(radius: CGFloat, edges: Edge.Set) -> Self {
        Self(radius: radius, attachedEdges: edges)
    }
}

public enum PopupBackground: Sendable, Equatable {
    case color(Color)
}

public enum BackdropPolicy: Sendable, Equatable {
    case none
    case color(Color, opacity: Double)
}

public enum PopupTransition: Sendable, Equatable {
    case identity
    case opacity
    case scaleAndOpacity
    case moveFrom(Edge)
    case moveTo(Edge)

    public static func move(from edge: Edge) -> Self {
        .moveFrom(edge)
    }

    public static func move(to edge: Edge) -> Self {
        .moveTo(edge)
    }
}

public enum OutsideInteractionPolicy: Sendable, Equatable {
    case consume
    case dismissTop
    case dismissToHitPopup
    case passThrough
}

public enum PopupKeyboardAvoidance: Sendable, Equatable {
    case none
    case moveIntoVisibleRegion
    case respectVisibleBottom
}

public enum PopupSafeAreaPolicy: Sendable, Equatable {
    case contained
    case ignored
}

public enum PopupDragDirection: Sendable, Equatable {
    case up
    case down
}

public struct DragPolicy: Sendable, Equatable {
    public var isEnabled: Bool
    public var direction: PopupDragDirection
    public var activationArea: CGFloat
    public var dismissalThreshold: Double

    public init(
        isEnabled: Bool = true,
        direction: PopupDragDirection,
        activationArea: CGFloat = 30,
        dismissalThreshold: Double = 1.0 / 3.0
    ) {
        self.isEnabled = isEnabled
        self.direction = direction
        self.activationArea = activationArea
        self.dismissalThreshold = dismissalThreshold
    }
}

public enum PopupDetent: Sendable, Equatable {
    case fixed(CGFloat)
    case fraction(CGFloat)
    case large
    case fullscreen
}

public enum StackAppearance: Sendable, Equatable {
    case flat
    case stacked
}

public enum PopupAnchorPoint: Sendable, Equatable {
    case topLeft
    case top
    case topRight
    case left
    case center
    case right
    case bottomLeft
    case bottom
    case bottomRight
}

public struct ScreenAvoidancePolicy: Sendable, Equatable {
    public var edges: Edge.Set
    public var padding: CGFloat

    public init(edges: Edge.Set, padding: CGFloat) {
        self.edges = edges
        self.padding = padding
    }
}

public protocol PopupSizingConfigurable: PopupConfiguration {
    var size: PopupSizePolicy { get set }
}

public protocol PopupPaddingConfigurable: PopupConfiguration {
    var padding: EdgeInsets { get set }
}

public extension PopupPaddingConfigurable {
    func padding(_ edges: Edge.Set = .all, _ length: CGFloat) -> Self {
        let value = max(0, length)
        var copy = self
        var insets = copy.padding

        if edges.contains(.top) {
            insets.top = value
        }
        if edges.contains(.leading) {
            insets.leading = value
        }
        if edges.contains(.bottom) {
            insets.bottom = value
        }
        if edges.contains(.trailing) {
            insets.trailing = value
        }

        copy.padding = insets
        return copy
    }
}

public extension PopupSizingConfigurable {
    func size(_ policy: PopupSizePolicy) -> Self {
        var copy = self
        copy.size = policy
        return copy
    }

    func size(width: PopupDimension, height: PopupDimension) -> Self {
        size(.dimensions(width: width, height: height))
    }
}

public protocol PopupVisualConfigurable: PopupConfiguration {
    var corners: PopupCorners { get set }
    var background: PopupBackground { get set }
    var backdrop: BackdropPolicy { get set }
}

public extension PopupVisualConfigurable {
    func corners(_ policy: PopupCorners) -> Self {
        var copy = self
        copy.corners = policy
        return copy
    }

    func background(_ policy: PopupBackground) -> Self {
        var copy = self
        copy.background = policy
        return copy
    }

    func backdrop(_ policy: BackdropPolicy) -> Self {
        var copy = self
        copy.backdrop = policy
        return copy
    }
}

public protocol PopupTransitionConfigurable: PopupConfiguration {
    var insertionTransition: PopupTransition { get set }
    var removalTransition: PopupTransition { get set }
}

public extension PopupTransitionConfigurable {
    func transition(insertion: PopupTransition, removal: PopupTransition) -> Self {
        var copy = self
        copy.insertionTransition = insertion
        copy.removalTransition = removal
        return copy
    }
}

public protocol PopupOutsideInteractionConfigurable: PopupConfiguration {
    var outsideInteraction: OutsideInteractionPolicy { get set }
}

public extension PopupOutsideInteractionConfigurable {
    func outsideInteraction(_ policy: OutsideInteractionPolicy) -> Self {
        var copy = self
        copy.outsideInteraction = policy
        return copy
    }
}

public protocol PopupDetentConfigurable: PopupConfiguration {
    var detents: [PopupDetent] { get set }
}

public protocol PopupSafeAreaConfigurable: PopupConfiguration {
    var safeArea: PopupSafeAreaPolicy { get set }
}

public extension PopupSafeAreaConfigurable {
    func safeArea(_ policy: PopupSafeAreaPolicy) -> Self {
        var copy = self
        copy.safeArea = policy
        return copy
    }
}

public protocol PopupDragConfigurable: PopupConfiguration {
    var drag: DragPolicy { get set }
}

public extension PopupDragConfigurable {
    func drag(
        isEnabled: Bool,
        activationArea: CGFloat? = nil,
        dismissalThreshold: Double? = nil
    ) -> Self {
        var copy = self
        var policy = copy.drag
        policy.isEnabled = isEnabled
        if let activationArea {
            policy.activationArea = max(0, activationArea)
        }
        if let dismissalThreshold {
            policy.dismissalThreshold = min(max(0, dismissalThreshold), 1)
        }
        copy.drag = policy
        return copy
    }
}

public protocol PopupStackAppearanceConfigurable: PopupConfiguration {
    var stackAppearance: StackAppearance { get set }
}

public extension PopupStackAppearanceConfigurable {
    func stackAppearance(_ appearance: StackAppearance) -> Self {
        var copy = self
        copy.stackAppearance = appearance
        return copy
    }
}

public extension PopupDetentConfigurable {
    func detents(_ values: [PopupDetent]) -> Self {
        var copy = self
        copy.detents = values
        return copy
    }
}
