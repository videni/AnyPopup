import CoreGraphics

enum PopupDimensionAxis {
    case width
    case height
}

extension PopupDimension {
    func resolvedLength(
        contentSize: CGSize,
        availableSize: CGSize,
        axis: PopupDimensionAxis
    ) -> CGFloat {
        let content = axis == .width ? contentSize.width : contentSize.height
        let available = axis == .width ? availableSize.width : availableSize.height

        let result: CGFloat = switch self {
        case .content:
            content
        case let .fixed(value):
            value
        case let .fraction(value):
            available * min(max(0, value), 1)
        case .fill:
            available
        case .availableWidth:
            availableSize.width
        case .availableHeight:
            availableSize.height
        case let .subtract(base, value):
            base.resolvedLength(
                contentSize: contentSize,
                availableSize: availableSize,
                axis: axis
            ) - value
        case let .lowerBound(base, minimum):
            max(
                base.resolvedLength(
                    contentSize: contentSize,
                    availableSize: availableSize,
                    axis: axis
                ),
                minimum
            )
        case let .upperBound(base, maximum):
            min(
                base.resolvedLength(
                    contentSize: contentSize,
                    availableSize: availableSize,
                    axis: axis
                ),
                maximum.resolvedLength(
                    contentSize: contentSize,
                    availableSize: availableSize,
                    axis: axis
                )
            )
        }
        return max(0, result)
    }

    func proposedLength(
        availableSize: CGSize,
        axis: PopupDimensionAxis
    ) -> CGFloat? {
        guard !dependsOnContent else {
            return nil
        }
        return resolvedLength(
            contentSize: .zero,
            availableSize: availableSize,
            axis: axis
        )
    }

    private var dependsOnContent: Bool {
        switch self {
        case .content:
            true
        case let .subtract(base, _), let .lowerBound(base, _):
            base.dependsOnContent
        case let .upperBound(base, maximum):
            base.dependsOnContent || maximum.dependsOnContent
        case .fixed, .fraction, .fill, .availableWidth, .availableHeight:
            false
        }
    }
}
