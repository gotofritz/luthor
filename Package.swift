// swift-tools-version:6.0
import PackageDescription

let package = Package(
  name: "Luthor",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "LuthorDomain", targets: ["LuthorDomain"]),
    .library(name: "LuthorStore", targets: ["LuthorStore"]),
  ],
  targets: [
    .target(name: "LuthorDomain"),
    .target(name: "LuthorStore", dependencies: ["LuthorDomain"]),
    .target(name: "LuthorTestSupport", dependencies: ["LuthorDomain"], path: "Tests/LuthorTestSupport"),
    .testTarget(name: "LuthorDomainTests", dependencies: ["LuthorDomain", "LuthorTestSupport"]),
    .testTarget(
      name: "LuthorStoreTests",
      dependencies: ["LuthorDomain", "LuthorStore", "LuthorTestSupport"]
    ),
  ]
)
