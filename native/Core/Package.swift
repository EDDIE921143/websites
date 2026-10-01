// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "EdizCore", platforms: [.iOS(.v17), .macOS(.v13)], products: [.library(name: "EdizCore", targets: ["EdizCore"])], targets: [.systemLibrary(name: "CSQLite"), .target(name: "EdizCore", dependencies: ["CSQLite"]), .testTarget(name: "EdizCoreTests", dependencies: ["EdizCore"])])
