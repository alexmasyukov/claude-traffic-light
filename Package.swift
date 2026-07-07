// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TrafficLight",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "TrafficLight",
            path: "Sources/TrafficLight"
        )
    ]
)
