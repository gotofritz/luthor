// swift-tools-version:6.0
import PackageDescription

let package = Package(
  name: "Luthor",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "LuthorDomain", targets: ["LuthorDomain"]),
    .library(name: "LuthorStore", targets: ["LuthorStore"]),
    .executable(name: "luthor", targets: ["luthor"]),
  ],
  targets: [
    .target(name: "LuthorDomain"),
    .target(name: "LuthorStore", dependencies: ["LuthorDomain"]),
    .target(name: "LuthorCLI", dependencies: ["LuthorDomain", "LuthorStore"]),
    .executableTarget(name: "luthor", dependencies: ["LuthorCLI"]),
    .target(name: "LuthorTestSupport", dependencies: ["LuthorDomain"], path: "Tests/LuthorTestSupport"),
    .testTarget(name: "LuthorDomainTests", dependencies: ["LuthorDomain", "LuthorTestSupport"]),
    .testTarget(
      name: "LuthorStoreTests",
      dependencies: ["LuthorDomain", "LuthorStore", "LuthorTestSupport"]
    ),
    .testTarget(
      name: "LuthorCLITests",
      dependencies: ["LuthorCLI", "LuthorDomain", "LuthorStore", "LuthorTestSupport"]
    ),
  ]
)
