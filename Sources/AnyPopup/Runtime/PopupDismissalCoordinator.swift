import Combine
import Foundation

public struct PopupDismissalBatchID: Sendable, Hashable {
    public let rawValue: UUID

    public init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

@MainActor
public struct PopupDismissalSnapshot: Identifiable {
    public nonisolated let id: PopupID
    public let popup: AnyPopup
    public let presentation: PopupPresentation
    public private(set) var isDeparting: Bool

    let batchID: PopupDismissalBatchID

    init(
        popup: AnyPopup,
        presentation: PopupPresentation,
        batchID: PopupDismissalBatchID
    ) {
        id = popup.id
        self.popup = popup
        self.presentation = presentation
        self.batchID = batchID
        isDeparting = false
    }

    mutating func markDeparting() {
        isDeparting = true
    }
}

@MainActor
public struct PopupDismissalBatch {
    public let id: PopupDismissalBatchID

    private let coordinator: PopupDismissalCoordinator

    init(id: PopupDismissalBatchID, coordinator: PopupDismissalCoordinator) {
        self.id = id
        self.coordinator = coordinator
    }

    public func wait() async {
        await coordinator.wait(for: id)
    }
}

@MainActor
public final class PopupDismissalCoordinator: ObservableObject {
    @Published public private(set) var snapshots: [PopupDismissalSnapshot] = []

    private struct ActiveBatch {
        var remainingPopupIDs: Set<PopupID>
        var continuations: [CheckedContinuation<Void, Never>] = []
    }

    private var interactionMap: PopupInteractionMap?
    private var activeBatches: [PopupDismissalBatchID: ActiveBatch] = [:]
    private var claimedPopupIDs: Set<PopupID> = []
    private weak var keyboardDismissal: (any PopupKeyboardDismissing)?
    private var isRenderingActive = false
    private var reduceMotion = false

    public init() {}

    func bindKeyboardDismissal(_ keyboardDismissal: any PopupKeyboardDismissing) {
        self.keyboardDismissal = keyboardDismissal
    }

    func waitBeforeDeparture(for popup: AnyPopup) async {
        guard let keyboardDismissal else { return }
        await PopupDismissalGate().waitBeforeDeparture(
            dismissKeyboard: popup.dismissKeyboardOnDismissal,
            keyboard: keyboardDismissal
        )
    }

    public func bindInteractionMap(_ interactionMap: PopupInteractionMap) {
        guard self.interactionMap !== interactionMap else { return }
        self.interactionMap?.cancelDismissals()
        self.interactionMap = interactionMap
        interactionMap.beginDismissal(count: snapshots.count)
    }

    public func configure(isRenderingActive: Bool, reduceMotion: Bool) {
        self.isRenderingActive = isRenderingActive
        self.reduceMotion = reduceMotion
        if !isRenderingActive || reduceMotion {
            cancelAll()
        }
    }

    func begin(_ popups: [AnyPopup]) -> PopupDismissalBatch? {
        guard isRenderingActive, !reduceMotion, !popups.isEmpty else { return nil }
        let presentations = Dictionary(
            uniqueKeysWithValues: (interactionMap?.snapshot().presentations ?? []).map {
                ($0.id, $0.presentation)
            }
        )
        let batchID = PopupDismissalBatchID()
        let newSnapshots = popups.compactMap { popup -> PopupDismissalSnapshot? in
            guard let presentation = presentations[popup.id] else { return nil }
            return PopupDismissalSnapshot(
                popup: popup,
                presentation: presentation,
                batchID: batchID
            )
        }
        guard !newSnapshots.isEmpty else { return nil }

        snapshots.append(contentsOf: newSnapshots)
        interactionMap?.beginDismissal(count: newSnapshots.count)
        activeBatches[batchID] = ActiveBatch(
            remainingPopupIDs: Set(newSnapshots.map(\.id))
        )
        return PopupDismissalBatch(id: batchID, coordinator: self)
    }

    public func claimStart(identity: PopupID) -> Bool {
        guard snapshots.contains(where: { $0.id == identity }),
            !claimedPopupIDs.contains(identity) else { return false }
        claimedPopupIDs.insert(identity)
        return true
    }

    public func markDeparting(identity: PopupID) {
        guard let index = snapshots.firstIndex(where: { $0.id == identity }) else { return }
        snapshots[index].markDeparting()
    }

    public func complete(identity: PopupID) {
        guard let index = snapshots.firstIndex(where: { $0.id == identity }) else { return }
        let batchID = snapshots[index].batchID
        snapshots.remove(at: index)
        claimedPopupIDs.remove(identity)
        interactionMap?.endDismissal()

        guard var batch = activeBatches[batchID] else { return }
        batch.remainingPopupIDs.remove(identity)
        guard batch.remainingPopupIDs.isEmpty else {
            activeBatches[batchID] = batch
            return
        }
        activeBatches.removeValue(forKey: batchID)
        resume(batch.continuations)
    }

    public func cancelAll() {
        snapshots.removeAll()
        claimedPopupIDs.removeAll()
        interactionMap?.cancelDismissals()
        let continuations = activeBatches.values.flatMap(\.continuations)
        activeBatches.removeAll()
        resume(continuations)
    }

    func wait(for batchID: PopupDismissalBatchID) async {
        guard activeBatches[batchID] != nil else { return }
        await withCheckedContinuation { continuation in
            guard var batch = activeBatches[batchID] else {
                continuation.resume()
                return
            }
            batch.continuations.append(continuation)
            activeBatches[batchID] = batch
        }
    }
}

private extension PopupDismissalCoordinator {
    func resume(_ continuations: [CheckedContinuation<Void, Never>]) {
        for continuation in continuations {
            continuation.resume()
        }
    }
}
