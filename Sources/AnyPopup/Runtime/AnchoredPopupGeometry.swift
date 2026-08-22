import SwiftUI

public struct AnchoredPopupGeometry: Sendable, Equatable {
    public let frame: CGRect
    public let sourcePoint: CGPoint
    public let popupAnchorPoint: CGPoint
    public let avoidanceShift: CGSize
    public let sourcePointInPopup: CGPoint

    public static func resolve(
        contentSize: CGSize,
        anchorFrame: CGRect,
        containerFrame: CGRect,
        config: AnchoredPopupConfig
    ) -> Self {
        let popupSize = ContainerPopupGeometry.resolvedSize(
            contentSize: contentSize,
            availableSize: containerFrame.size,
            policy: config.size,
            clampsToAvailableSize: false
        )
        let sourcePoint = point(for: config.sourceAnchor, in: anchorFrame)
        let localPopupAnchor = point(for: config.popupAnchor, in: CGRect(origin: .zero, size: popupSize))
        let initialFrame = CGRect(
            x: sourcePoint.x - localPopupAnchor.x + config.offset.width,
            y: sourcePoint.y - localPopupAnchor.y + config.offset.height,
            width: popupSize.width,
            height: popupSize.height
        )
        let frame = shiftedInsideContainer(
            frame: initialFrame,
            containerFrame: containerFrame,
            policy: config.screenAvoidance
        )
        let shift = CGSize(
            width: frame.minX - initialFrame.minX,
            height: frame.minY - initialFrame.minY
        )

        return Self(
            frame: frame,
            sourcePoint: sourcePoint,
            popupAnchorPoint: point(for: config.popupAnchor, in: frame),
            avoidanceShift: shift,
            sourcePointInPopup: CGPoint(
                x: sourcePoint.x - frame.minX,
                y: sourcePoint.y - frame.minY
            )
        )
    }
}

private extension AnchoredPopupGeometry {
    static func point(for anchor: PopupAnchorPoint, in frame: CGRect) -> CGPoint {
        switch anchor {
        case .topLeft:
            CGPoint(x: frame.minX, y: frame.minY)
        case .top:
            CGPoint(x: frame.midX, y: frame.minY)
        case .topRight:
            CGPoint(x: frame.maxX, y: frame.minY)
        case .left:
            CGPoint(x: frame.minX, y: frame.midY)
        case .center:
            CGPoint(x: frame.midX, y: frame.midY)
        case .right:
            CGPoint(x: frame.maxX, y: frame.midY)
        case .bottomLeft:
            CGPoint(x: frame.minX, y: frame.maxY)
        case .bottom:
            CGPoint(x: frame.midX, y: frame.maxY)
        case .bottomRight:
            CGPoint(x: frame.maxX, y: frame.maxY)
        }
    }

    static func shiftedInsideContainer(
        frame: CGRect,
        containerFrame: CGRect,
        policy: ScreenAvoidancePolicy
    ) -> CGRect {
        guard !policy.edges.isEmpty else { return frame }

        var result = frame
        if policy.edges.contains(.horizontal) {
            let minX = containerFrame.minX + policy.padding
            let maxX = containerFrame.maxX - policy.padding
            if result.minX < minX {
                result.origin.x = minX
            }
            if result.maxX > maxX {
                result.origin.x -= result.maxX - maxX
            }
        }
        if policy.edges.contains(.vertical) {
            let minY = containerFrame.minY + policy.padding
            let maxY = containerFrame.maxY - policy.padding
            if result.minY < minY {
                result.origin.y = minY
            }
            if result.maxY > maxY {
                result.origin.y -= result.maxY - maxY
            }
        }
        return result
    }
}
