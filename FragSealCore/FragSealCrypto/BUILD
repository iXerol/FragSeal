load("//Tools/Swift:linux_swift_toolchain.bzl", "linux_cc_copts", "linux_swift_copts")
load("//Tools/Swift:mixed_clang_swift_module.bzl", "mixed_clang_swift_module")

config_setting(
    name = "use_common_override",
    define_values = {"DECRYPTER_IMPL": "commoncrypto"},
)

config_setting(
    name = "use_openssl_override",
    define_values = {"DECRYPTER_IMPL": "openssl"},
)

config_setting(
    name = "mac_default_backend",
    constraint_values = ["@platforms//os:macos"],
    define_values = {"DECRYPTER_IMPL": ""},
)

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
    generate_submodules = True,
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
        ":use_common_override": ["FRAGSEAL_USE_COMMONCRYPTO"],
        ":use_openssl_override": ["FRAGSEAL_USE_OPENSSL"],
        ":mac_default_backend": ["FRAGSEAL_USE_COMMONCRYPTO"],
        "//conditions:default": ["FRAGSEAL_USE_OPENSSL"],
    }),
    deps = ["@openssl_local//:openssl_headers"],
    visibility = [
        "//FragSealCore:__pkg__",
        "//FragSealCoreTests:__pkg__",
    ],
)
