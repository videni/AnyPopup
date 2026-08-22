import Foundation

@MainActor
public final class KeyboardManagerIntegration {
    public static let shared = KeyboardManagerIntegration()

    private var installedSceneSessionIDs: Set<String> = []

    public init() {}

    @discardableResult
    public func installOnce(
        sceneSessionID: String,
        _ installation: @MainActor () -> Void
    ) -> Bool {
        guard installedSceneSessionIDs.insert(sceneSessionID).inserted else { return false }
        installation()
        return true
    }
}
