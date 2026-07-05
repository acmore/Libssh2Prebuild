// swift-tools-version:5.6

import PackageDescription

let package = Package(
    name: "CSSH",
    products: [
        .library(name: "CSSH", targets: ["CSSH"])
    ],
    targets: [
        .binaryTarget(name: "CSSH",
                      url: "https://github.com/acmore/Libssh2Prebuild/releases/download/1.11.1-openssl-3.5.7/CSSH-1.11.1-openssl-3.5.7.xcframework.zip",
                      checksum: "8cda0a4a7e24f9de33ba98f26f4e16206658df8e7a5c2e0b7c874e2187b555fc")
    ]
)
