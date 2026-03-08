load("@rules_apple//apple:apple.bzl", "apple_universal_binary")
load(
    "@rules_swift//swift:swift.bzl",
    "swift_binary",
    "swift_library",
)
load("//Tools/Swift:linux_swift_toolchain.bzl", "linux_swift_copts")
load("//Tools/Swift:swift_compatibility.bzl", "swift_compatibility_dylib")

config_setting(
    name = "is_macos",
    constraint_values = ["@platforms//os:macos"],
)

swift_library(
    name = "FragSeal_library",
    srcs = glob([
        "**/*.swift",
    ]),
    deps = [
        "//FragSealCore:FragSealCore",
        "@swiftpkg_swift_argument_parser//:ArgumentParser",
    ],
    visibility = ["//visibility:private"],
    copts = [
        "-Xcc", "-std=c++20",
        "-parse-as-library",
        "-strict-concurrency=complete",
        "-cxx-interoperability-mode=default",
        "-enable-experimental-feature", "SafeInteropWrappers",
    ] + linux_swift_copts(),
)

swift_binary(
    name = "fragseal",
    visibility = ["//visibility:public"],
    deps = [
        ":FragSeal_library",
    ],
    linkopts = select({
        ":is_macos": [
            "-Wl,-rpath,@executable_path",
            "-Wl,-rpath,@executable_path/Frameworks",
        ],
        "//conditions:default": [],
    }),
)

swift_binary(
    name = "fragseal_cli_linux",
    deps = [":FragSeal_library"],
    visibility = ["//visibility:public"],
    target_compatible_with = ["@platforms//os:linux"],
)

apple_universal_binary(
    name = "fragseal_arm64",
    binary = ":fragseal",
    forced_cpus = ["arm64"],
    minimum_os_version = "14.0",
    platform_type = "macos",
    visibility = ["//visibility:public"],
)

apple_universal_binary(
    name = "fragseal_x86_64",
    binary = ":fragseal",
    forced_cpus = ["x86_64"],
    minimum_os_version = "14.0",
    platform_type = "macos",
    visibility = ["//visibility:public"],
)

apple_universal_binary(
    name = "universal_fragseal",
    binary = ":fragseal",
    forced_cpus = [
        "x86_64",
        "arm64",
    ],
    minimum_os_version = "14.0",
    platform_type = "macos",
    visibility = ["//visibility:public"],
)

swift_compatibility_dylib(
    name = "libswiftCompatibilitySpan",
)

genrule(
    name = "fragseal_backdeploy_bundle_arm64",
    srcs = [
        ":fragseal_arm64",
        ":libswiftCompatibilitySpan",
    ],
    outs = [
        "arm64/fragseal_backdeploy",
        "arm64/Frameworks/libswiftCompatibilitySpan.dylib",
    ],
    cmd = """
set -euo pipefail
out_dir="$(@D)/arm64"
cp "$(location :fragseal_arm64)" "$${out_dir}/fragseal_backdeploy"
mkdir -p "$${out_dir}/Frameworks"
cp "$(location :libswiftCompatibilitySpan)" "$${out_dir}/Frameworks/libswiftCompatibilitySpan.dylib"
chmod +x "$${out_dir}/fragseal_backdeploy"
""",
)

genrule(
    name = "fragseal_backdeploy_bundle_x86_64",
    srcs = [
        ":fragseal_x86_64",
        ":libswiftCompatibilitySpan",
    ],
    outs = [
        "x86_64/fragseal_backdeploy",
        "x86_64/Frameworks/libswiftCompatibilitySpan.dylib",
    ],
    cmd = """
set -euo pipefail
out_dir="$(@D)/x86_64"
cp "$(location :fragseal_x86_64)" "$${out_dir}/fragseal_backdeploy"
mkdir -p "$${out_dir}/Frameworks"
cp "$(location :libswiftCompatibilitySpan)" "$${out_dir}/Frameworks/libswiftCompatibilitySpan.dylib"
chmod +x "$${out_dir}/fragseal_backdeploy"
""",
)

genrule(
    name = "fragseal_backdeploy_bundle",
    srcs = [
        ":universal_fragseal",
        ":libswiftCompatibilitySpan",
    ],
    outs = [
        "fragseal_backdeploy",
        "Frameworks/libswiftCompatibilitySpan.dylib",
    ],
    visibility = ["//visibility:public"],
    cmd = """
set -euo pipefail
out_dir="$(@D)"
cp "$(location :universal_fragseal)" "$${out_dir}/fragseal_backdeploy"
mkdir -p "$${out_dir}/Frameworks"
cp "$(location :libswiftCompatibilitySpan)" "$${out_dir}/Frameworks/libswiftCompatibilitySpan.dylib"
chmod +x "$${out_dir}/fragseal_backdeploy"
""",
)
