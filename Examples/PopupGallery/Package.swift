// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PopupGallery",
    platforms: [.iOS("26.0")],
    products: [
        .executable(name: "PopupGallery", targets: ["PopupGallery"])
    ],
    dependencies: [
        .package(path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "PopupGallery",
            dependencies: ["AnyPopup"],
            path: "Sources"
        )
    ],
    swiftLanguageModes: [.v6]
)
