// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "生存计划",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "生存计划",
            targets: ["生存计划"]),
    ],
    targets: [
        .target(
            name: "生存计划",
            path: "SurvivalPlan",
            resources: [
                .process("Resources")
            ]
        ),
    ]
)
