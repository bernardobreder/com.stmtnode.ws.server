// swift-tools-version:4.2

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
        .package(url: "git@github.com:bernardobreder/com.stmtnode.lock.git", .branch("master")),
    ],
    targets: [
        .target(
            name: "com.stmtnode.ws.server",
            dependencies: ["com.stmtnode.net", "com.stmtnode.secure", "com.stmtnode.string", "com.stmtnode.lock"]),
        .testTarget(
            name: "com.stmtnode.ws.serverTests",
            dependencies: ["com.stmtnode.ws.server", "com.stmtnode.net", "com.stmtnode.secure", "com.stmtnode.string", "com.stmtnode.lock"]),
    ]
)
