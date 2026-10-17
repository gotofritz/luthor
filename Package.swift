// swift-tools-version:6.0
import PackageDescription

let package = Package(
  name: "Luthor",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "LuthorDomain", targets: ["LuthorDomain"]),
    .library(name: "LuthorStore", targets: ["LuthorStore"]),
    .library(name: "LuthorViewModels", targets: ["LuthorViewModels"]),
    .executable(name: "luthor", targets: ["luthor"]),
  ],
  targets: [
    .target(name: "LuthorDomain"),
    .target(name: "LuthorStore", dependencies: ["LuthorDomain"]),
    .target(name: "LuthorCLI", dependencies: ["LuthorDomain", "LuthorStore"]),
    .target(name: "LuthorViewModels", dependencies: ["LuthorDomain", "LuthorStore"]),
    .executableTarget(name: "luthor", dependencies: ["LuthorCLI", "LuthorStore"]),
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
      name: "LuthorCLITests",
      dependencies: ["LuthorCLI", "LuthorDomain", "LuthorStore", "LuthorTestSupport"]
    ),
    .testTarget(
      name: "LuthorViewModelsTests",
      dependencies: ["LuthorViewModels", "LuthorDomain", "LuthorStore", "LuthorTestSupport"]
    ),
  ]
)
