// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "KDownloadFileInterop",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "KDownloadFileInterop",
            targets: ["KDownloadFileInterop"]
        ),
    ],
    targets: [
        .target(
            name: "KDownloadFileInterop",
            swiftSettings: [
                .define("LIVE_ACTIVITY_ENABLED", .when(platforms: [.iOS], configuration: .release)),
//                 .unsafeFlags([
//                     "-emit-objc-header",
//                     "-emit-objc-header-path", "./Headers/KDownloadFileInterop-Swift.h"
//                 ])
//            ]
        )
    ]
)
