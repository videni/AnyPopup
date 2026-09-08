import Foundation

enum PopupRenderPhase: Equatable {
    case active
    case awaitingDeparture
    case departing
}

@MainActor
struct PopupRenderEntry: Identifiable {
    nonisolated let id: PopupID
    let popup: AnyPopup
    let snapshot: PopupDismissalSnapshot?
    let activeIndex: Int?
    let phase: PopupRenderPhase

    var dismissalTaskID: PopupID? {
        snapshot?.id
    }

    var zIndex: Double {
        snapshot?.presentation.zIndex ?? Double(activeIndex ?? 0)
    }

    static func resolve(
        active: [AnyPopup],
        dismissing: [PopupDismissalSnapshot]
    ) -> [PopupRenderEntry] {
        var entries = active.enumerated().map { index, popup in
            PopupRenderEntry(
                id: popup.id,
                popup: popup,
                snapshot: nil,
                activeIndex: index,
                phase: .active
            )
        }
        for snapshot in dismissing {
            let entry = PopupRenderEntry(
                id: snapshot.id,
                popup: snapshot.popup,
                snapshot: snapshot,
                activeIndex: nil,
                phase: snapshot.isDeparting ? .departing : .awaitingDeparture
            )
            if let index = entries.firstIndex(where: { $0.id == snapshot.id }) {
                entries[index] = entry
            } else {
                entries.append(entry)
            }
        }
        return entries.sorted { lhs, rhs in
            if lhs.zIndex == rhs.zIndex {
                return lhs.id.rawValue.uuidString < rhs.id.rawValue.uuidString
            }
            return lhs.zIndex < rhs.zIndex
        }
    }
}
