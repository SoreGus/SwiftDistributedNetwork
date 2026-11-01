// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "SwiftDistributedNetwork",
    platforms: [
        .macOS(.v27),
        .iOS(.v27)
    ],
    products: [
        .library(
            name: "SwiftDistributedNetworkContracts",
            targets: [
                "Contracts"
            ]
        ),
        .library(
            name: "SwiftDistributedNetworkHost",
            targets: [
                "Host"
            ]
        ),
        .library(
            name: "SwiftDistributedNetworkClient",
            targets: [
                "Client"
            ]
        )
    ],
    targets: [
        .target(
            name: "Contracts",
            swiftSettings: [
                .enableUpcomingFeature(
                    "ApproachableConcurrency"
                )
            ]
        ),
        .target(
            name: "Host",
            dependencies: [
                "Contracts"
            ],
            swiftSettings: [
                .enableUpcomingFeature(
                    "ApproachableConcurrency"
                )
            ]
        ),
        .target(
            name: "Client",
            dependencies: [
                "Contracts"
            ],
            swiftSettings: [
                .enableUpcomingFeature(
                    "ApproachableConcurrency"
                )
            ]
        ),
        .testTarget(
            name: "ContractsTests",
            dependencies: [
                "Contracts"
            ]
        ),
        .testTarget(
            name: "HostTests",
            dependencies: [
                "Host",
                "Contracts"
            ]
        ),
        .testTarget(
            name: "ClientTests",
            dependencies: [
                "Client",
                "Contracts",
                "Host"
            ]
        ),
    ]
)
