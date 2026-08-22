import Foundation
import SwiftUI

public struct PopupLayoutItem: Sendable, Equatable {
    public let id: PopupID
    public let presentation: PopupPresentation

    public init(id: PopupID, presentation: PopupPresentation) {
        self.id = id
        self.presentation = presentation
    }
}

public struct PopupLayoutFailure: Sendable, Equatable {
    public let id: PopupID
    public let error: PopupPresentationError

    public init(id: PopupID, error: PopupPresentationError) {
        self.id = id
        self.error = error
    }
}

public struct PopupLayoutPlan: Sendable, Equatable {
    public let items: [PopupLayoutItem]
    public let backdrops: [PopupBackdropLayer]
    public let shieldPlacements: [PopupShieldPlacement]
    public let interactionRegions: [PopupInteractionRegion<PopupID>]
    public let failures: [PopupLayoutFailure]

    public var shieldCount: Int { shieldPlacements.count }

    public init(
        items: [PopupLayoutItem],
        backdrops: [PopupBackdropLayer],
        shieldPlacements: [PopupShieldPlacement],
        interactionRegions: [PopupInteractionRegion<PopupID>],
        failures: [PopupLayoutFailure]
    ) {
        self.items = items
        self.backdrops = backdrops
        self.shieldPlacements = shieldPlacements
        self.interactionRegions = interactionRegions
        self.failures = failures
    }

    @MainActor
    public static func resolve(
        popups: [AnyPopup],
        environment: PopupEnvironment,
        contentSizes: [PopupID: CGSize],
        defaults: PopupDefaults = PopupDefaults(),
        trackedAnchorFrames: [String: CGRect] = [:]
    ) -> Self {
        let inputs = popups.map { popup in
            PopupLayoutInput(
                id: popup.id,
                configuration: popup.configuration,
                anchorFrame: anchorFrame(
                    source: popup.anchorSource,
                    trackedAnchorFrames: trackedAnchorFrames
                )
            )
        }
        return resolve(
            inputs: inputs,
            environment: environment,
            contentSizes: contentSizes,
            defaults: defaults
        )
    }
}

extension PopupLayoutPlan {
    static func resolve(
        inputs: [PopupLayoutInput],
        environment: PopupEnvironment,
        contentSizes: [PopupID: CGSize],
        defaults: PopupDefaults
    ) -> Self {
        var items: [PopupLayoutItem] = []
        var failures: [PopupLayoutFailure] = []

        for (index, input) in inputs.enumerated() {
            let contentSize = contentSizes[input.id] ?? .zero
            switch input.configuration {
            case let .container(config):
                let presentation = PopupPresentationResolver.resolve(
                    config: config,
                    environment: environment,
                    contentSize: contentSize,
                    defaults: defaults,
                    zIndex: Double(index)
                )
                items.append(PopupLayoutItem(id: input.id, presentation: presentation))
            case let .anchored(config):
                do {
                    let presentation = try PopupPresentationResolver.resolve(
                        config: config,
                        environment: environment,
                        contentSize: contentSize,
                        anchorFrame: input.anchorFrame,
                        defaults: defaults,
                        zIndex: Double(index)
                    )
                    items.append(PopupLayoutItem(id: input.id, presentation: presentation))
                } catch let error as PopupPresentationError {
                    failures.append(PopupLayoutFailure(id: input.id, error: error))
                } catch {
                    failures.append(PopupLayoutFailure(id: input.id, error: .invalidAnchorFrame))
                }
            }
        }

        let policies = items.map(\.presentation.backdrop)
        let regions = items.map {
            PopupInteractionRegion(id: $0.id, frame: $0.presentation.frame)
        }
        return Self(
            items: items,
            backdrops: BackdropComposition.resolve(policies),
            shieldPlacements: ShieldPlan.resolve(popupCount: items.count),
            interactionRegions: regions,
            failures: failures
        )
    }
}

struct PopupLayoutInput: Sendable {
    let id: PopupID
    let configuration: AnyPopupConfiguration
    let anchorFrame: CGRect?
}

public final class PopupInteractionMap: @unchecked Sendable {
    public struct Snapshot: Sendable, Equatable {
        public let regions: [PopupInteractionRegion<PopupID>]
        public let topPolicy: OutsideInteractionPolicy?

        public init(
            regions: [PopupInteractionRegion<PopupID>],
            topPolicy: OutsideInteractionPolicy?
        ) {
            self.regions = regions
            self.topPolicy = topPolicy
        }
    }

    private let lock = NSLock()
    private var current = Snapshot(regions: [], topPolicy: nil)

    public init() {}

    public func publish(_ plan: PopupLayoutPlan) {
        let snapshot = Snapshot(
            regions: plan.interactionRegions,
            topPolicy: plan.items.last?.presentation.outsideInteraction
        )
        lock.withLock {
            current = snapshot
        }
    }

    public func snapshot() -> Snapshot {
        lock.withLock { current }
    }

    public func action(
        at point: CGPoint,
        gesture: PopupInteractionGesture = .idle
    ) -> OutsideInteractionAction<PopupID> {
        let snapshot = snapshot()
        guard let topPolicy = snapshot.topPolicy else {
            return .passThrough(to: nil)
        }
        return OutsideInteractionRouter.action(
            at: point,
            regions: snapshot.regions,
            topPolicy: topPolicy,
            gesture: gesture
        )
    }
}

private extension PopupLayoutPlan {
    static func anchorFrame(
        source: PopupAnchorSource?,
        trackedAnchorFrames: [String: CGRect]
    ) -> CGRect? {
        switch source {
        case let .frame(frame):
            frame
        case let .tracked(anchorID):
            trackedAnchorFrames[anchorID]
        case nil:
            nil
        }
    }
}

struct PopupLayout: Layout {
    struct Cache {
        var plan = PopupLayoutPlan(
            items: [],
            backdrops: [],
            shieldPlacements: [],
            interactionRegions: [],
            failures: []
        )
    }

    let inputs: [PopupLayoutInput]
    let environment: PopupEnvironment
    let defaults: PopupDefaults
    let interactionMap: PopupInteractionMap

    func makeCache(subviews: Subviews) -> Cache {
        Cache()
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) -> CGSize {
        let contentSizes = measuredContentSizes(subviews: subviews)
        cache.plan = PopupLayoutPlan.resolve(
            inputs: inputs,
            environment: environment,
            contentSizes: contentSizes,
            defaults: defaults
        )
        interactionMap.publish(cache.plan)
        return environment.containerSize
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) {
        let itemsByID = Dictionary(uniqueKeysWithValues: cache.plan.items.map { ($0.id, $0) })
        for subview in subviews {
            switch subview[PopupLayoutRoleKey.self] {
            case let .popup(id):
                guard let item = itemsByID[id] else { continue }
                let frame = item.presentation.frame
                subview.place(
                    at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(frame.size)
                )
            case let .backdrop(id):
                guard itemsByID[id] != nil else { continue }
                placeFullScreen(subview, in: bounds)
            case .shield:
                guard cache.plan.shieldCount > 0 else { continue }
                placeFullScreen(subview, in: bounds)
            case .unmanaged:
                continue
            }
        }
    }
}

enum PopupLayoutRole {
    case popup(PopupID)
    case backdrop(PopupID)
    case shield
    case unmanaged
}

private struct PopupLayoutRoleKey: LayoutValueKey {
    static let defaultValue = PopupLayoutRole.unmanaged
}

extension View {
    func popupLayoutRole(_ role: PopupLayoutRole) -> some View {
        layoutValue(key: PopupLayoutRoleKey.self, value: role)
    }
}

private extension PopupLayout {
    func measuredContentSizes(subviews: Subviews) -> [PopupID: CGSize] {
        var result: [PopupID: CGSize] = [:]
        let inputsByID = Dictionary(uniqueKeysWithValues: inputs.map { ($0.id, $0) })
        for subview in subviews {
            guard case let .popup(id) = subview[PopupLayoutRoleKey.self],
                let input = inputsByID[id] else { continue }
            let measured = subview.sizeThatFits(
                measurementProposal(for: input.configuration)
            )
            result[id] = normalized(measured)
        }
        return result
    }

    func measurementProposal(
        for configuration: AnyPopupConfiguration
    ) -> ProposedViewSize {
        let size: PopupSizePolicy
        switch configuration {
        case let .container(config):
            switch config.resolve(in: environment, defaults: defaults).presentation {
            case let .center(value):
                size = value.size
            case let .top(value):
                size = value.size
            case let .bottom(value):
                size = value.size
            }
        case let .anchored(config):
            size = config.applying(defaults: defaults.anchored).size
        }

        switch size {
        case .content:
            return .unspecified
        case let .dimensions(width, height):
            return ProposedViewSize(
                width: proposedLength(width, available: environment.availableWidth),
                height: proposedLength(height, available: environment.availableHeight)
            )
        }
    }

    func proposedLength(_ dimension: PopupDimension, available: CGFloat) -> CGFloat? {
        switch dimension {
        case .content:
            nil
        case let .fixed(value):
            max(0, value)
        case let .fraction(value):
            available * min(max(0, value), 1)
        case .fill:
            available
        }
    }

    func normalized(_ size: CGSize) -> CGSize {
        CGSize(
            width: size.width.isFinite ? max(0, size.width) : 0,
            height: size.height.isFinite ? max(0, size.height) : 0
        )
    }

    func placeFullScreen(_ subview: LayoutSubview, in bounds: CGRect) {
        subview.place(
            at: bounds.origin,
            anchor: .topLeading,
            proposal: ProposedViewSize(bounds.size)
        )
    }
}
