// swift-tools-version:6.0
import PackageDescription

let package = Package(
  name: "Luthor",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "LuthorDomain", targets: ["LuthorDomain"]),
    .library(name: "LuthorStore", targets: ["LuthorStore"]),
    .library(name: "LuthorViewModels", targets: ["LuthorViewModels"]),
  ],
  dependencies: [
    // Reads and writes the YAML text export (EventText).
    .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.3")
  ],
  targets: [
    .target(name: "LuthorDomain"),
    .target(name: "LuthorStore", dependencies: ["LuthorDomain", .product(name: "Yams", package: "Yams")]),
    .target(name: "LuthorViewModels", dependencies: ["LuthorDomain", "LuthorStore"]),
    .target(
      name: "LuthorTestSupport",
      dependencies: ["LuthorDomain", "LuthorStore"],
      path: "Tests/LuthorTestSupport"
    ),
    .testTarget(name: "LuthorDomainTests", dependencies: ["LuthorDomain", "LuthorTestSupport"]),
    .testTarget(
      name: "LuthorStoreTests",
      dependencies: ["LuthorDomain", "LuthorStore", "LuthorTestSupport"]
    ),
    .testTarget(
      name: "LuthorViewModelsTests",
      dependencies: ["LuthorViewModels", "LuthorDomain", "LuthorStore", "LuthorTestSupport"]
    ),
    // End-to-end flows through the view models; `make test-acceptance` runs them alone.
    .testTarget(
      name: "LuthorAcceptanceTests",
      dependencies: ["LuthorDomain", "LuthorStore", "LuthorViewModels", "LuthorTestSupport"]
    ),
  ]
)
