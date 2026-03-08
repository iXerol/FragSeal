load("@rules_swift//swift:swift.bzl", "swift_library")
load("//Tools/Swift:linux_swift_toolchain.bzl", "linux_swift_copts")

swift_library(
    name = "FragSealCore",
    module_name = "FragSealCore",
    srcs = glob([
        "**/*.swift",
    ], exclude = [
        "FileSystem/**/*.swift",
        "FragSealTomlCodec/**/*.swift",
    ]),
    deps = [
        "//FragSealCore/FileSystem:FragSealFileSystem",
        "//FragSealCore/FragSealCrypto:FragSealCrypto",
        "//FragSealCore/FragSealTomlCodec:FragSealTomlCodec",
        "@swiftpkg_aws_sdk_swift//:AWSS3",
        "@swiftpkg_smithy_swift//:Smithy",
        "@swiftpkg_swift_system//:SystemPackage",
    ],
    visibility = ["//visibility:public"],
    copts = [
        "-Xcc", "-std=c++20",
        "-strict-concurrency=complete",
        "-cxx-interoperability-mode=default",
        "-enable-experimental-feature", "SafeInteropWrappers",
    ] + linux_swift_copts(),
)
