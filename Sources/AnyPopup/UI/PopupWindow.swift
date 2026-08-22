import CoreGraphics

public enum PopupWindowHitTarget: Sendable, Equatable {
    case popup(PopupID)
    case shield
    case passThrough
}

public enum PopupWindowRouting {
    public static func hitTarget(
        at point: CGPoint,
        interactionMap: PopupInteractionMap
    ) -> PopupWindowHitTarget {
        let snapshot = interactionMap.snapshot()
        guard !snapshot.isDismissalBlocking else { return .shield }
        guard let topRegion = snapshot.regions.last else { return .passThrough }
        if topRegion.frame.contains(point) {
            return .popup(topRegion.id)
        }

        guard snapshot.topPolicy == .passThrough else { return .shield }
        guard let hit = snapshot.regions.dropLast().last(where: { $0.frame.contains(point) }) else {
            return .passThrough
        }
        return .popup(hit.id)
    }
}

#if canImport(UIKit)
import UIKit

public final class PopupWindow: UIWindow {
    public let interactionMap: PopupInteractionMap

    public init(windowScene: UIWindowScene, interactionMap: PopupInteractionMap) {
        self.interactionMap = interactionMap
        super.init(windowScene: windowScene)
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    public override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        PopupWindowRouting.hitTarget(at: point, interactionMap: interactionMap) != .passThrough
    }

    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard PopupWindowRouting.hitTarget(at: point, interactionMap: interactionMap) != .passThrough else {
            return nil
        }
        return super.hitTest(point, with: event)
    }
}
#endif
