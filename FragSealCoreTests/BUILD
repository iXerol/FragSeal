load("@rules_swift//swift:swift.bzl", "swift_library", "swift_test")
load("@rules_apple//apple:macos.bzl", "macos_unit_test")
load("@rules_apple//apple/testing/default_runner:macos_test_runner.bzl", "macos_test_runner")
load("//Tools/Swift:linux_swift_toolchain.bzl", "linux_swift_copts")
load("//Tools/Swift:swift_compatibility.bzl", "swift_compatibility_dylib")

macos_test_runner(
    name = "macos_runner",
)

TEST_SRCS = glob([
    "**/*.swift",
], exclude = [
    "Constants.template.swift",
    "LinuxTestMain.swift",
],)

TEST_DATA = glob([
    "Resources/**",
])

swift_library(
    name = "FragSealCoreTests_library",
    testonly = True,
    srcs = TEST_SRCS,
    data = TEST_DATA,
    deps = [
        "//FragSealCore:FragSealCore",
        "@swiftpkg_swift_system//:SystemPackage",
    ],
    visibility = ["//visibility:private"],
    copts = [
        "-Xcc", "-std=c++20",
        "-strict-concurrency=complete",
        "-cxx-interoperability-mode=default",
        "-enable-experimental-feature", "SafeInteropWrappers",
    ] + linux_swift_copts(),
    features = ["-swift.symbol_graphs"],
)

swift_test(
    name = "FragSealCoreTests_host",
    srcs = ["LinuxTestMain.swift"],
    deps = [":FragSealCoreTests_library"],
    data = TEST_DATA,
    copts = [
        "-Xcc", "-std=c++20",
        "-strict-concurrency=complete",
        "-cxx-interoperability-mode=default",
        "-enable-experimental-feature", "SafeInteropWrappers",
    ] + linux_swift_copts(),
    discover_tests = False,
    features = ["-swift.symbol_graphs"],
)

objc_library(
    name = "FragSealCryptoSwiftHeaderImportObjc",
    testonly = True,
    srcs = ["ObjC/FragSealCryptoSwiftHeaderImportTest.mm"],
    deps = [
        "//FragSealCore/FragSealCrypto:FragSealCrypto",
    ],
    copts = [
        "-std=c++20",
    ],
    sdk_frameworks = ["Foundation", "XCTest"],
    alwayslink = True,
)

macos_unit_test(
    name = "FragSealCoreTests_backdeploy",
    minimum_os_version = "14.0",
    additional_contents = {
        ":libswiftCompatibilitySpan": "Frameworks",
    },
    deps = [
        ":FragSealCoreTests_library",
        ":FragSealCryptoSwiftHeaderImportObjc",
    ],
    runner = ":macos_runner",
    visibility = ["//visibility:public"],
)

macos_unit_test(
    name = "FragSealCoreTests",
    minimum_os_version = "26.0",
    deps = [
        ":FragSealCoreTests_library",
        ":FragSealCryptoSwiftHeaderImportObjc",
    ],
    runner = ":macos_runner",
    visibility = ["//visibility:public"],
)
swift_compatibility_dylib(
    name = "libswiftCompatibilitySpan",
)
