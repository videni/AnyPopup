import AnyPopup
import SwiftUI

@main
struct PopupGalleryApp: App {
    var body: some Scene {
        WindowGroup {
            GalleryRootView()
                .registerPopups { defaults in
                    defaults
                        .vertical { vertical in
                            vertical.outsideInteraction(.dismissTop)
                        }
                        .anchored { anchored in
                            anchored.outsideInteraction(.dismissTop)
                        }
                }
        }
    }
}

private struct GalleryRootView: View {
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
                                    .present(anchoredTo: menuAnchorID)
                            }
                        }
                        .trackAnchor(menuAnchorID)
                    }
                }
            }
            .navigationTitle("AnyPopup Gallery")
        }
    }
}
