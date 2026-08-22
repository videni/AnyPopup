import CoreGraphics

public enum PopupVerticalEdge: Sendable, Equatable {
    case top
    case bottom
}

public struct PopupDragConfiguration: Sendable, Equatable {
    public let edge: PopupVerticalEdge
    public let isEnabled: Bool
    public let activationArea: CGFloat
    public let dismissalThreshold: Double
    public let detents: [PopupDetent]

    public static func top(
        isEnabled: Bool = true,
        activationArea: CGFloat = 30,
        dismissalThreshold: Double = 1.0 / 3.0,
        detents: [PopupDetent] = []
    ) -> Self {
        Self(
            edge: .top,
            isEnabled: isEnabled,
            activationArea: activationArea,
            dismissalThreshold: dismissalThreshold,
            detents: detents
        )
    }

    public static func bottom(
        isEnabled: Bool = true,
        activationArea: CGFloat = 30,
        dismissalThreshold: Double = 1.0 / 3.0,
        detents: [PopupDetent] = []
    ) -> Self {
        Self(
            edge: .bottom,
            isEnabled: isEnabled,
            activationArea: activationArea,
            dismissalThreshold: dismissalThreshold,
            detents: detents
        )
    }
}

public enum DragResolution: Sendable, Equatable {
    case cancel
    case dismiss
    case snap(height: CGFloat)
}

public enum DragController {
    static func localStartLocation(
        globalLocation: CGFloat,
        popupFrame: CGRect
    ) -> CGFloat {
        globalLocation - popupFrame.minY
    }

    public static func isValidStart(
        location: CGFloat,
        extent: CGFloat,
        configuration: PopupDragConfiguration
    ) -> Bool {
        guard configuration.isEnabled,
            location.isFinite,
            extent.isFinite,
            extent > 0 else { return false }
        let activationArea = min(max(0, configuration.activationArea), extent)
        switch configuration.edge {
        case .top:
            return location >= extent - activationArea
        case .bottom:
            return location <= activationArea
        }
    }

    public static func resolve(
        translation: CGFloat,
        velocity: CGFloat,
        extent: CGFloat,
        currentHeight: CGFloat,
        contentHeight: CGFloat,
        configuration: PopupDragConfiguration,
        largeExtent: CGFloat? = nil
    ) -> DragResolution {
        guard configuration.isEnabled,
            translation.isFinite,
            velocity.isFinite,
            extent.isFinite,
            extent > 0,
            currentHeight.isFinite,
            contentHeight.isFinite else { return .cancel }

        let projectedTranslation = translation + velocity * velocityProjectionDuration
        let threshold = CGFloat(min(max(configuration.dismissalThreshold, 0), 1))
        let outwardProgress = max(
            0,
            projectedTranslation * configuration.edge.outwardMultiplier / max(1, currentHeight)
        )
        if outwardProgress >= threshold {
            return .dismiss
        }
        guard !configuration.detents.isEmpty else { return .cancel }

        var targets = resolvedDetentHeights(
            configuration.detents,
            contentHeight: contentHeight,
            extent: extent,
            largeExtent: largeExtent ?? extent
        )
        let normalizedCurrentHeight = min(max(0, currentHeight), extent)
        targets.append(normalizedCurrentHeight)
        targets = Array(Set(targets)).sorted()

        let heightDelta = projectedTranslation * configuration.edge.expansionMultiplier
        guard heightDelta != 0 else { return .cancel }
        let proposedHeight = min(max(0, normalizedCurrentHeight + heightDelta), extent)
        let targetHeight: CGFloat
        if heightDelta > 0 {
            targetHeight = targets.first(where: { $0 >= proposedHeight }) ?? targets.last ?? normalizedCurrentHeight
        } else {
            targetHeight = targets.last(where: { $0 <= proposedHeight }) ?? targets.first ?? normalizedCurrentHeight
        }
        let distanceToTarget = abs(targetHeight - normalizedCurrentHeight)
        guard distanceToTarget > 0 else { return .cancel }

        let progress = abs(proposedHeight - normalizedCurrentHeight) / distanceToTarget
        return progress >= threshold ? .snap(height: targetHeight) : .cancel
    }

    public static func resolvedDetentHeights(
        _ detents: [PopupDetent],
        contentHeight: CGFloat,
        extent: CGFloat,
        largeExtent: CGFloat
    ) -> [CGFloat] {
        let normalizedExtent = max(0, extent)
        let normalizedLargeExtent = min(max(0, largeExtent), normalizedExtent)
        let heights = detents.map { detent -> CGFloat in
            switch detent {
            case let .fixed(height):
                height
            case let .fraction(fraction):
                normalizedExtent * fraction
            case .large:
                normalizedLargeExtent
            case .fullscreen:
                normalizedExtent
            }
        } + [contentHeight]

        let normalizedHeights = heights.map { height in
            guard height.isFinite else { return CGFloat.zero }
            return min(max(0, height), normalizedExtent)
        }
        return Array(Set(normalizedHeights)).sorted()
    }
}

private extension DragController {
    static let velocityProjectionDuration: CGFloat = 0.15
}

private extension PopupVerticalEdge {
    var outwardMultiplier: CGFloat {
        switch self {
        case .top: -1
        case .bottom: 1
        }
    }

    var expansionMultiplier: CGFloat {
        -outwardMultiplier
    }
}
