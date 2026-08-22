import Foundation

@MainActor
final class PopupPresentationStore: ObservableObject {
    @Published private var anchoredGeometries: [PopupID: AnchoredPopupGeometry] = [:]

    func anchoredGeometry(for popupID: PopupID) -> AnchoredPopupGeometry? {
        anchoredGeometries[popupID]
    }

    func publish(_ plan: PopupLayoutPlan) {
        let next = Dictionary(uniqueKeysWithValues: plan.items.compactMap { item in
            item.presentation.anchoredGeometry.map { (item.id, $0) }
        })
        guard next != anchoredGeometries else { return }
        anchoredGeometries = next
    }
}
