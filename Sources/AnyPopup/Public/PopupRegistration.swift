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
    func popupAnchorRegistrationContext(_ context: PopupAnchorRegistrationContext?) -> some View {
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

private struct PopupAnchorRegistrationModifier: ViewModifier {
    @Environment(\.popupAnchorRegistrationContext) private var context
    @State private var latestFrame: CGRect?

    let anchorID: String
    let popupStackID: PopupStackID?

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .global)
            } action: { frame in
                guard PopupGeometryValidation.isValidAnchorFrame(frame) else { return }
                latestFrame = frame
                updateFrame(frame, context: context)
            }
            .onChange(of: context) { oldContext, newContext in
                if let oldContext {
                    removeFrame(context: oldContext)
                }
                guard let latestFrame else { return }
                updateFrame(latestFrame, context: newContext)
            }
            .onDisappear {
                guard let context else { return }
                removeFrame(context: context)
            }
    }

    @MainActor
    private func updateFrame(
        _ frame: CGRect,
        context: PopupAnchorRegistrationContext?
    ) {
        guard let context else { return }
        _ = AnchorRegistry.shared.setFrame(
            frame,
            from: context.sourceCoordinateSpace,
            to: context.popupCoordinateSpace,
            for: key(context)
        )
    }

    @MainActor
    private func removeFrame(context: PopupAnchorRegistrationContext) {
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

#if canImport(UIKit)
import UIKit

public extension View {
    func registerPopups(
        id: PopupStackID = .shared,
        configBuilder: @escaping (PopupDefaults) -> PopupDefaults = { $0 },
        keyboardManagerInstaller: (@MainActor (UIViewController.Type) -> Void)? = nil
    ) -> some View {
        modifier(PopupSceneRegistrationModifier(
            popupStackID: id,
            defaults: configBuilder(PopupDefaults()),
            keyboardManagerInstaller: keyboardManagerInstaller
        ))
    }
}

@MainActor
private final class PopupSceneRegistrationState: ObservableObject {
    @Published var anchorContext: PopupAnchorRegistrationContext?
}

private struct PopupSceneRegistrationModifier: ViewModifier {
    @StateObject private var state = PopupSceneRegistrationState()

    @Environment(\.locale) private var locale
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let popupStackID: PopupStackID
    let defaults: PopupDefaults
    let keyboardManagerInstaller: (@MainActor (UIViewController.Type) -> Void)?

    func body(content: Content) -> some View {
        content
            .environment(\.popupAnchorRegistrationContext, state.anchorContext)
            .background(
                PopupSceneAttachment(
                    popupStackID: popupStackID,
                    defaults: defaults,
                    keyboardManagerInstaller: keyboardManagerInstaller,
                    locale: locale,
                    layoutDirection: layoutDirection,
                    colorScheme: colorScheme,
                    dynamicTypeSize: dynamicTypeSize,
                    reduceMotion: reduceMotion,
                    state: state
                )
                .frame(width: 0, height: 0)
            )
    }
}

private struct PopupSceneAttachment: UIViewRepresentable {
    let popupStackID: PopupStackID
    let defaults: PopupDefaults
    let keyboardManagerInstaller: (@MainActor (UIViewController.Type) -> Void)?
    let locale: Locale
    let layoutDirection: LayoutDirection
    let colorScheme: ColorScheme?
    let dynamicTypeSize: DynamicTypeSize
    let reduceMotion: Bool
    let state: PopupSceneRegistrationState

    final class Coordinator {
        var didApplyDefaults = false
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        guard let sourceWindow = view.window,
            let windowScene = sourceWindow.windowScene else { return }
        let controller = PopupSceneControllerRegistry.shared.controller(
            windowScene: windowScene,
            popupStackID: popupStackID,
            defaults: defaults
        )
        if !context.coordinator.didApplyDefaults {
            controller.update(defaults: defaults)
            context.coordinator.didApplyDefaults = true
        }
        controller.start()
        if let keyboardManagerInstaller {
            KeyboardManagerIntegration.shared.installOnce(
                sceneSessionID: controller.sceneSessionID
            ) {
                keyboardManagerInstaller(PopupHostingController.self)
            }
        }
        controller.updateEnvironment(
            locale: locale,
            layoutDirection: layoutDirection,
            colorScheme: colorScheme,
            dynamicTypeSize: dynamicTypeSize,
            reduceMotion: reduceMotion
        )
        let anchorContext = controller.anchorRegistrationContext(
            sourceWindow: sourceWindow
        )
        guard state.anchorContext != anchorContext else { return }
        DispatchQueue.main.async { [weak state] in
            state?.anchorContext = anchorContext
        }
    }
}
#endif
