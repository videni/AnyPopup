import CoreGraphics

public struct PopupStackItemAppearance: Sendable, Equatable {
    public let transform: PopupTransform
    public let opacity: Double
    public let overlayOpacity: Double
    public let zIndex: Double
}

public extension StackAppearance {
    func resolve(
        popupCount: Int,
        edge: PopupVerticalEdge,
        activeDismissalProgress: CGFloat
    ) -> [PopupStackItemAppearance] {
        guard popupCount > 0 else { return [] }
        let progress = min(max(0, activeDismissalProgress), 1)

        return (0..<popupCount).map { index in
            let invertedIndex = popupCount - 1 - index
            guard self == .stacked, invertedIndex > 0 else {
                return PopupStackItemAppearance(
                    transform: .identity,
                    opacity: 1,
                    overlayOpacity: 0,
                    zIndex: Double(index)
                )
            }

            let remainingProgress = 1 - progress
            let scaleProgress = invertedIndex == 1
                ? remainingProgress
                : max(0.7, remainingProgress)
            let overlayProgress = invertedIndex == 1
                ? remainingProgress
                : max(0.6, remainingProgress)
            let offsetDirection: CGFloat = edge == .top ? 1 : -1

            return PopupStackItemAppearance(
                transform: PopupTransform(
                    translation: CGSize(
                        width: 0,
                        height: CGFloat(invertedIndex) * 8 * offsetDirection
                    ),
                    scale: 1 - CGFloat(invertedIndex) * 0.025 * scaleProgress
                ),
                opacity: invertedIndex < 3 ? 1 : 0,
                overlayOpacity: min(
                    1,
                    max(0, Double(CGFloat(invertedIndex) * 0.2 * overlayProgress))
                ),
                zIndex: Double(index)
            )
        }
    }
}
