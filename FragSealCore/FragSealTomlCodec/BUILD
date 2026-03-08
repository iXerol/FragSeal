load("//Tools/Swift:linux_swift_toolchain.bzl", "linux_cc_copts", "linux_swift_copts")
load("//Tools/Swift:mixed_clang_swift_module.bzl", "mixed_clang_swift_module")

config_setting(
    name = "is_linux",
    constraint_values = ["@platforms//os:linux"],
)

CLANG_BUILTIN_HEADERS_DEPS = select({
    ":is_linux": ["@clang_builtin_include//:lifetimebound_headers"],
    "//conditions:default": [],
})

SWIFT_TOOLCHAIN_HEADERS_DEPS = select({
    ":is_linux": ["@swift_toolchain_include//:swift_bridging_headers"],
    "//conditions:default": [],
})

mixed_clang_swift_module(
    name = "FragSealTomlCodec",
    srcs = glob([
        "*.swift",
        "*.cpp",
        "include/**/*.hpp",
    ]),
    hdrs = [
        "include/FragSealTomlCodec.hpp",
    ],
    copts = ["-std=c++20"],
    swift_copts = [
        "-Xcc", "-std=c++20",
        "-strict-concurrency=complete",
        "-cxx-interoperability-mode=default",
        "-enable-experimental-feature", "SafeInteropWrappers",
    ] + linux_swift_copts(),
    clang_header_copts = linux_cc_copts(),
    header_deps = CLANG_BUILTIN_HEADERS_DEPS + SWIFT_TOOLCHAIN_HEADERS_DEPS,
    deps = [
        "@tomlplusplus//:tomlplusplus",
    ],
    visibility = [
        "//FragSealCore:__pkg__",
        "//FragSealCoreTests:__pkg__",
    ],
)
