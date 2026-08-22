import AnyPopup
import SwiftUI

struct AnchoredMenuPopup: Popup {
    let popupConfig = AnchoredPopupConfig()
        .size(width: .fixed(240), height: .content)
        .anchor(source: .bottomRight, popup: .topRight)
        .offset(x: 0, y: 8)
        .screenAvoidance(edges: .all, padding: 16)
        .outsideInteraction(.dismissTop)
        .when(
            .availableWidthLessThan(500),
            use: AnchoredPopupConfig()
                .size(width: .fixed(200), height: .content)
                .anchor(source: .bottomRight, popup: .topRight)
                .offset(x: 0, y: 8)
                .screenAvoidance(edges: .all, padding: 12)
                .outsideInteraction(.dismissTop)
        )

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            menuItem("Copy", systemImage: "doc.on.doc")
            Divider()
            menuItem("Share", systemImage: "square.and.arrow.up")
            Divider()
            menuItem("Delete", systemImage: "trash", role: .destructive)
        }
        .padding(.vertical, 8)
    }

    private func menuItem(
        _ title: String,
        systemImage: String,
        role: ButtonRole? = nil
    ) -> some View {
        Button(role: role) {
            Task { await dismissLastPopup() }
        } label: {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
    }
}
