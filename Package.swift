// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AnyPopup",
    platforms: [
        .iOS("26.0"),
        .macOS(.v14)
    ],
    products: [
        .library(name: "AnyPopup", targets: ["AnyPopup"])
    ],
    targets: [
        .target(name: "AnyPopup"),
        .testTarget(name: "AnyPopupTests", dependencies: ["AnyPopup"])
    ],
    swiftLanguageModes: [.v6]
)
