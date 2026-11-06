// swift-tools-version:5.6

import PackageDescription

let package = Package(
    name: "CSSH",
    products: [
        .library(name: "CSSH", targets: ["CSSH"])
    ],
    targets: [
        .binaryTarget(name: "CSSH",
                      url: "https://github.com/acmore/Libssh2Prebuild/releases/download/1.11.2-dev.373022ad-openssl-3.5.9/CSSH-1.11.2-dev.373022ad-openssl-3.5.9.xcframework.zip",
                      checksum: "70bfe218ba53760d574909af8ec7c65f96f58972aa0ef328ac05e83d925c520e")
    ]
)
