import Combine
import CoreGraphics

public struct PopupCoordinateSpace: Sendable, Equatable {
    public let transformToScene: CGAffineTransform

    public static let popupView = Self(transformToScene: .identity)

    public init(transformToScene: CGAffineTransform) {
        self.transformToScene = transformToScene
    }
}

public enum AnchorCoordinateConversionError: Error, Sendable, Equatable {
    case invalidSourceFrame
    case invalidSourceTransform
    case nonInvertibleDestination
    case invalidConvertedFrame
}

public enum AnchorCoordinateConverter {
    public static func convert(
        _ frame: CGRect,
        from source: PopupCoordinateSpace,
        to destination: PopupCoordinateSpace
    ) throws -> CGRect {
        guard PopupGeometryValidation.isValidAnchorFrame(frame) else {
            throw AnchorCoordinateConversionError.invalidSourceFrame
        }
        guard PopupGeometryValidation.isFinite(source.transformToScene) else {
            throw AnchorCoordinateConversionError.invalidSourceTransform
        }
        let destinationTransform = destination.transformToScene
        let determinant = destinationTransform.a * destinationTransform.d
            - destinationTransform.b * destinationTransform.c
        guard PopupGeometryValidation.isFinite(destinationTransform),
            determinant.isFinite,
            abs(determinant) > .ulpOfOne else {
            throw AnchorCoordinateConversionError.nonInvertibleDestination
        }

        let converted = frame
            .applying(source.transformToScene)
            .applying(destinationTransform.inverted())
        guard PopupGeometryValidation.isValidAnchorFrame(converted) else {
            throw AnchorCoordinateConversionError.invalidConvertedFrame
        }
        return converted
    }
}

public enum AnchorRegistryError: Sendable, Equatable {
    case invalidFrame(AnchorRegistry.Key)
    case conversionFailed(AnchorRegistry.Key, AnchorCoordinateConversionError)
}

@MainActor
public final class AnchorRegistry: ObservableObject {
    public struct Key: Sendable, Hashable {
        public let sceneSessionID: String
        public let popupStackID: PopupStackID
        public let anchorID: String

        public init(
            sceneSessionID: String,
            popupStackID: PopupStackID,
            anchorID: String
        ) {
            self.sceneSessionID = sceneSessionID
            self.popupStackID = popupStackID
            self.anchorID = anchorID
        }
    }

    public static let shared = AnchorRegistry()

    @Published public private(set) var revision: UInt64 = 0
    public private(set) var lastError: AnchorRegistryError?

    private var frames: [Key: CGRect] = [:]

    public init() {}

    @discardableResult
    public func setFrame(_ frame: CGRect, for key: Key) -> Bool {
        guard PopupGeometryValidation.isValidAnchorFrame(frame) else {
            removeFrame(for: key)
            lastError = .invalidFrame(key)
            return false
        }
        guard frames[key] != frame else {
            lastError = nil
            return true
        }

        frames[key] = frame
        lastError = nil
        revision &+= 1
        return true
    }

    @discardableResult
    public func setFrame(
        _ frame: CGRect,
        from source: PopupCoordinateSpace,
        to destination: PopupCoordinateSpace,
        for key: Key
    ) -> Bool {
        do {
            let converted = try AnchorCoordinateConverter.convert(
                frame,
                from: source,
                to: destination
            )
            return setFrame(converted, for: key)
        } catch let error as AnchorCoordinateConversionError {
            removeFrame(for: key)
            lastError = .conversionFailed(key, error)
            return false
        } catch {
            removeFrame(for: key)
            lastError = .conversionFailed(key, .invalidConvertedFrame)
            return false
        }
    }

    public func frame(for key: Key) -> CGRect? {
        frames[key]
    }

    public func removeFrame(for key: Key) {
        guard frames.removeValue(forKey: key) != nil else { return }
        revision &+= 1
    }

    public func removeAll(sceneSessionID: String) {
        let keys = frames.keys.filter { $0.sceneSessionID == sceneSessionID }
        guard !keys.isEmpty else { return }
        for key in keys {
            frames.removeValue(forKey: key)
        }
        revision &+= 1
    }
}

enum PopupGeometryValidation {
    static func isValidAnchorFrame(_ frame: CGRect) -> Bool {
        !frame.isNull
            && !frame.isInfinite
            && frame.width > 0
            && frame.height > 0
            && frame.origin.x.isFinite
            && frame.origin.y.isFinite
            && frame.width.isFinite
            && frame.height.isFinite
    }

    static func isFinite(_ transform: CGAffineTransform) -> Bool {
        transform.a.isFinite
            && transform.b.isFinite
            && transform.c.isFinite
            && transform.d.isFinite
            && transform.tx.isFinite
            && transform.ty.isFinite
    }
}
