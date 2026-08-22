import SwiftUI

public struct PopupAnchorRegistrationContext: Sendable, Equatable {
    public let sceneSessionID: String
    public let popupStackID: PopupStackID
    public let sourceCoordinateSpace: PopupCoordinateSpace
    public let popupCoordinateSpace: PopupCoordinateSpace

    public init(
        sceneSessionID: String,
        popupStackID: PopupStackID = .shared,
        sourceCoordinateSpace: PopupCoordinateSpace,
        popupCoordinateSpace: PopupCoordinateSpace
    ) {
        self.sceneSessionID = sceneSessionID
        self.popupStackID = popupStackID
        self.sourceCoordinateSpace = sourceCoordinateSpace
        self.popupCoordinateSpace = popupCoordinateSpace
    }
}

public extension View {
    func popupAnchorRegistrationContext(_ context: PopupAnchorRegistrationContext) -> some View {
        environment(\.popupAnchorRegistrationContext, context)
    }

    func trackAnchor(
        _ anchorID: String,
        popupStackID: PopupStackID? = nil
    ) -> some View {
        modifier(PopupAnchorRegistrationModifier(
            anchorID: anchorID,
            popupStackID: popupStackID
        ))
    }
}

private struct PopupAnchorRegistrationContextKey: EnvironmentKey {
    static let defaultValue: PopupAnchorRegistrationContext? = nil
}

private extension EnvironmentValues {
    var popupAnchorRegistrationContext: PopupAnchorRegistrationContext? {
        get { self[PopupAnchorRegistrationContextKey.self] }
        set { self[PopupAnchorRegistrationContextKey.self] = newValue }
    }
}

private struct PopupAnchorFramePreferenceKey: PreferenceKey {
    static let defaultValue = CGRect.zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private struct PopupAnchorRegistrationModifier: ViewModifier {
    @Environment(\.popupAnchorRegistrationContext) private var context

    let anchorID: String
    let popupStackID: PopupStackID?

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: PopupAnchorFramePreferenceKey.self,
                        value: proxy.frame(in: .global)
                    )
                }
            )
            .onPreferenceChange(PopupAnchorFramePreferenceKey.self, perform: updateFrame)
            .onDisappear(perform: removeFrame)
    }

    @MainActor
    private func updateFrame(_ frame: CGRect) {
        guard let context else { return }
        _ = AnchorRegistry.shared.setFrame(
            frame,
            from: context.sourceCoordinateSpace,
            to: context.popupCoordinateSpace,
            for: key(context)
        )
    }

    @MainActor
    private func removeFrame() {
        guard let context else { return }
        AnchorRegistry.shared.removeFrame(for: key(context))
    }

    private func key(_ context: PopupAnchorRegistrationContext) -> AnchorRegistry.Key {
        AnchorRegistry.Key(
            sceneSessionID: context.sceneSessionID,
            popupStackID: popupStackID ?? context.popupStackID,
            anchorID: anchorID
        )
    }
}
