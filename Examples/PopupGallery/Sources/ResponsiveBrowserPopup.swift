import AnyPopup
import SwiftUI

struct ResponsiveBrowserPopup: Popup {
    let popupConfig = ContainerPopupConfig.center(
        CenterPopupConfig()
            .size(width: .fixed(720), height: .fraction(0.78))
            .transition(insertion: .opacity, removal: .opacity)
            .outsideInteraction(.dismissTop)
    )
    .when(
        .availableWidthLessThan(600),
        use: .bottom(
            BottomPopupConfig()
                .size(width: .fill, height: .fraction(0.9))
                .outsideInteraction(.dismissTop)
                .drag(isEnabled: true)
                .detents([.fraction(0.55), .large, .fullscreen])
        )
    )
    .layoutTransition(.move(from: .bottom))

    @State private var address = "https://example.com"
    @State private var notes = "Resize the window: this state must survive Center ↔ Bottom."

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                TextField("Address", text: $address)
                    .textFieldStyle(.roundedBorder)
                Button("Close") {
                    Task { await dismissPopup("browser") }
                }
            }

            ScrollView {
                TextEditor(text: $notes)
                    .frame(minHeight: 500)
                    .padding()
            }
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(20)
    }
}
