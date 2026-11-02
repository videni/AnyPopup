import AnyPopup
import SwiftUI

@main
struct PopupGalleryApp: App {
    var body: some Scene {
        WindowGroup {
            GalleryRootView()
                .registerPopups(configBuilder: { defaults in
                    defaults
                        .top { $0.outsideInteraction(.dismissTop) }
                        .bottom { $0.outsideInteraction(.dismissTop) }
                        .anchored { anchored in
                            anchored.outsideInteraction(.dismissTop)
                        }
                })
        }
    }
}

private struct GalleryRootView: View {
    @StateObject private var menuStack = PopupStack(id: PopupStackID("gallery-menu"))
    private let menuAnchorID = "gallery-menu"

    var body: some View {
        NavigationStack {
            Form {
                Section("Container") {
                    Button("Responsive Browser") {
                        Task {
                            await ResponsiveBrowserPopup()
                                .setCustomID("browser")
                                .present()
                        }
                    }
                }

                Section("Anchored") {
                    HStack {
                        Spacer()
                        Button("Edge Menu") {
                            Task {
                                await AnchoredMenuPopup()
                                    .present(anchoredTo: menuAnchorID, popupStackID: menuStack.id)
                            }
                        }
                        .popupAnchor(menuAnchorID, popupStackID: menuStack.id)
                    }
                }
            }
            .navigationTitle("AnyPopup Gallery")
        }
        .popupContainer(popupStack: menuStack)
    }
}
