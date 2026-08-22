import CoreGraphics

public enum ContainerPopupGeometry {
    public static func center(
        contentSize: CGSize,
        availableFrame: CGRect,
        config: CenterPopupConfig
    ) -> CGRect {
        frame(
            contentSize: contentSize,
            availableFrame: availableFrame,
            sizePolicy: config.size,
            verticalPosition: .center
        )
    }

    public static func top(
        contentSize: CGSize,
        availableFrame: CGRect,
        config: TopPopupConfig
    ) -> CGRect {
        frame(
            contentSize: contentSize,
            availableFrame: availableFrame,
            sizePolicy: config.size,
            verticalPosition: .top
        )
    }

    public static func bottom(
        contentSize: CGSize,
        availableFrame: CGRect,
        config: BottomPopupConfig
    ) -> CGRect {
        frame(
            contentSize: contentSize,
            availableFrame: availableFrame,
            sizePolicy: config.size,
            verticalPosition: .bottom
        )
    }
}

extension ContainerPopupGeometry {
    static func resolvedSize(
        contentSize: CGSize,
        availableSize: CGSize,
        policy: PopupSizePolicy,
        clampsToAvailableSize: Bool
    ) -> CGSize {
        let normalizedContent = CGSize(
            width: max(0, contentSize.width),
            height: max(0, contentSize.height)
        )
        let normalizedAvailable = CGSize(
            width: max(0, availableSize.width),
            height: max(0, availableSize.height)
        )

        let proposed: CGSize
        switch policy {
        case .content:
            proposed = normalizedContent
        case let .dimensions(width, height):
            proposed = CGSize(
                width: resolve(
                    width,
                    content: normalizedContent.width,
                    available: normalizedAvailable.width
                ),
                height: resolve(
                    height,
                    content: normalizedContent.height,
                    available: normalizedAvailable.height
                )
            )
        }

        guard clampsToAvailableSize else { return proposed }
        return CGSize(
            width: min(proposed.width, normalizedAvailable.width),
            height: min(proposed.height, normalizedAvailable.height)
        )
    }
}

private extension ContainerPopupGeometry {
    enum VerticalPosition {
        case top
        case center
        case bottom
    }

    static func frame(
        contentSize: CGSize,
        availableFrame: CGRect,
        sizePolicy: PopupSizePolicy,
        verticalPosition: VerticalPosition
    ) -> CGRect {
        let size = resolvedSize(
            contentSize: contentSize,
            availableSize: availableFrame.size,
            policy: sizePolicy,
            clampsToAvailableSize: true
        )
        let originY: CGFloat
        switch verticalPosition {
        case .top:
            originY = availableFrame.minY
        case .center:
            originY = availableFrame.midY - size.height / 2
        case .bottom:
            originY = availableFrame.maxY - size.height
        }

        return CGRect(
            x: availableFrame.midX - size.width / 2,
            y: originY,
            width: size.width,
            height: size.height
        )
    }

    static func resolve(
        _ dimension: PopupDimension,
        content: CGFloat,
        available: CGFloat
    ) -> CGFloat {
        switch dimension {
        case .content:
            content
        case let .fixed(value):
            max(0, value)
        case let .fraction(value):
            available * min(max(0, value), 1)
        case .fill:
            available
        }
    }
}
