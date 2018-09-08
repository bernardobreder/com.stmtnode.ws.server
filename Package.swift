// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "com.stmtnode.ws.server",
    products: [
        .library(
            name: "com.stmtnode.ws.server",
            targets: ["com.stmtnode.ws.server"]),
    ],
    dependencies: [
        .package(url: "git@github.com:bernardobreder/com.stmtnode.net.git", .branch("master")),
        .package(url: "git@github.com:bernardobreder/com.stmtnode.secure.git", .branch("master")),
        .package(url: "git@github.com:bernardobreder/com.stmtnode.string.git", .branch("master")),
    ],
    targets: [
        .target(
            name: "com.stmtnode.ws.server",
            dependencies: ["com.stmtnode.net", "com.stmtnode.secure", "com.stmtnode.string"]),
        .testTarget(
            name: "com.stmtnode.ws.serverTests",
            dependencies: ["com.stmtnode.ws.server", "com.stmtnode.net", "com.stmtnode.secure", "com.stmtnode.string"]),
    ]
)
