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
  targets: [
    .target(name: "LuthorDomain"),
    .target(name: "LuthorStore", dependencies: ["LuthorDomain"]),
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
