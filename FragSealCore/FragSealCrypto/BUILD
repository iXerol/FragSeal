load("//Tools/Swift:linux_swift_toolchain.bzl", "linux_cc_copts", "linux_swift_copts")
load("//Tools/Swift:mixed_clang_swift_module.bzl", "mixed_clang_swift_module")
load("@openssl_local//:availability.bzl", "OPENSSL_AVAILABLE")

config_setting(
    name = "is_linux",
    constraint_values = ["@platforms//os:linux"],
)

config_setting(
    name = "is_macos",
    constraint_values = ["@platforms//os:macos"],
)

CLANG_BUILTIN_HEADERS_DEPS = select({
    ":is_linux": ["@clang_builtin_include//:lifetimebound_headers"],
    "//conditions:default": [],
})

SWIFT_TOOLCHAIN_HEADERS_DEPS = select({
    ":is_linux": ["@swift_toolchain_include//:swift_bridging_headers"],
    "//conditions:default": [],
})

COMMON_DEFINES = ["FRAGSEAL_USE_COMMONCRYPTO"]
MODERN_OPENSSL_DEFINES = ["FRAGSEAL_USE_OPENSSL", "FRAGSEAL_ENABLE_OPENSSL"] if OPENSSL_AVAILABLE else []
MACOS_DEFINES = COMMON_DEFINES + MODERN_OPENSSL_DEFINES
LINUX_DEFINES = MODERN_OPENSSL_DEFINES

mixed_clang_swift_module(
    name = "FragSealCrypto",
    srcs = glob([
        "*.swift",
        "*.cpp",
        "include/**/*.hpp",
        "private/**/*.hpp",
    ]),
    hdrs = [
        "include/FragSealCrypto.hpp",
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
    defines = select({
        ":is_macos": MACOS_DEFINES,
        ":is_linux": LINUX_DEFINES,
        "//conditions:default": MODERN_OPENSSL_DEFINES,
    }),
    deps = ["@openssl_local//:openssl_headers"] if OPENSSL_AVAILABLE else [],
    visibility = [
        "//FragSealCore:__pkg__",
        "//FragSealCoreTests:__pkg__",
    ],
)
