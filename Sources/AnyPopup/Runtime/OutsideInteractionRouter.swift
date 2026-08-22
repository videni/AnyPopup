import CoreGraphics

public struct PopupInteractionRegion<ID: Sendable & Hashable>: Sendable, Equatable {
    public let id: ID
    public let frame: CGRect

    public init(id: ID, frame: CGRect) {
        self.id = id
        self.frame = frame
    }
}

public enum PopupInteractionGesture: Sendable, Equatable {
    case idle
    case dragging
}

public enum OutsideInteractionAction<ID: Sendable & Hashable>: Sendable, Equatable {
    case routeToPopup(ID)
    case consume
    case passThrough(to: ID?)
    case dismissTop
    case dismissSuffix(above: ID)
    case dismissAll
}

public enum OutsideInteractionRouter {
    public static func action<ID: Sendable & Hashable>(
        at point: CGPoint,
        regions: [PopupInteractionRegion<ID>],
        topPolicy: OutsideInteractionPolicy,
        gesture: PopupInteractionGesture
    ) -> OutsideInteractionAction<ID> {
        guard let topRegion = regions.last else {
            return .passThrough(to: nil)
        }
        if topRegion.frame.contains(point) {
            return .routeToPopup(topRegion.id)
        }
        guard gesture == .idle else { return .consume }

        switch topPolicy {
        case .consume:
            return .consume
        case .dismissTop:
            return .dismissTop
        case .dismissToHitPopup:
            guard let hit = regions.dropLast().last(where: { $0.frame.contains(point) }) else {
                return .dismissAll
            }
            return .dismissSuffix(above: hit.id)
        case .passThrough:
            let target = regions.dropLast().last(where: { $0.frame.contains(point) })?.id
            return .passThrough(to: target)
        }
    }
}
