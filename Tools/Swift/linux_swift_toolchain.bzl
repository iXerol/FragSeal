load("@swift_toolchain_include//:paths.bzl", "SWIFT_TOOLCHAIN_INCLUDE_ROOT", "SWIFT_TOOLCHAIN_SWIFT_TO_CXX_PARENT")

def _linux_libstdcpp_triple_swift_copts():
    return select({
        "@platforms//cpu:x86_64": [
            "-Xcc", "-Iexternal/libstdcpp/include/x86_64-linux-gnu/c++",
        ],
        "@platforms//cpu:aarch64": [
            "-Xcc", "-Iexternal/libstdcpp/include/aarch64-linux-gnu/c++",
        ],
        "//conditions:default": [],
    })

def _linux_libstdcpp_triple_cc_copts():
    return select({
        "@platforms//cpu:x86_64": [
            "-Iexternal/libstdcpp/include/x86_64-linux-gnu/c++",
        ],
        "@platforms//cpu:aarch64": [
            "-Iexternal/libstdcpp/include/aarch64-linux-gnu/c++",
        ],
        "//conditions:default": [],
    })

def linux_swift_copts():
    return select({
        "@platforms//os:linux": [
            "-module-alias", "System=SystemPackage",
            "-Xcc", "-stdlib=libstdc++",
            "-Xcc", "-I{}".format(SWIFT_TOOLCHAIN_INCLUDE_ROOT),
        ] + ([
            "-Xcc", "-I{}".format(SWIFT_TOOLCHAIN_SWIFT_TO_CXX_PARENT),
        ] if SWIFT_TOOLCHAIN_SWIFT_TO_CXX_PARENT else []) + [
            "-Xcc", "-Iexternal/libstdcpp/include/c++",
        ],
        "//conditions:default": [],
    }) + _linux_libstdcpp_triple_swift_copts()

def linux_cc_includes():
    return []

def linux_cc_copts():
    return select({
        "@platforms//os:linux": [
            "-I{}".format(SWIFT_TOOLCHAIN_INCLUDE_ROOT),
        ] + ([
            "-I{}".format(SWIFT_TOOLCHAIN_SWIFT_TO_CXX_PARENT),
        ] if SWIFT_TOOLCHAIN_SWIFT_TO_CXX_PARENT else []) + [
            "-Iexternal/libstdcpp/include/c++",
        ],
        "//conditions:default": [],
    }) + _linux_libstdcpp_triple_cc_copts()
