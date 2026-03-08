sh_test(
    name = "FragSealCliFunctionalTest_linux",
    srcs = ["cli_artifact_functional_test.sh"],
    args = [
        "native",
        "$(rootpath //FragSeal:fragseal_cli_linux)",
    ],
    data = ["//FragSeal:fragseal_cli_linux"],
    target_compatible_with = ["@platforms//os:linux"],
)

sh_test(
    name = "FragSealCliFunctionalTest_macos",
    srcs = ["cli_artifact_functional_test.sh"],
    args = [
        "native",
        "$(rootpath //FragSeal:universal_fragseal)",
    ],
    data = ["//FragSeal:universal_fragseal"],
    target_compatible_with = ["@platforms//os:macos"],
)

sh_test(
    name = "FragSealCliFunctionalTest_backdeploy",
    srcs = ["cli_artifact_functional_test.sh"],
    args = [
        "backdeploy",
        "FragSeal/fragseal_backdeploy",
        "FragSeal/Frameworks/libswiftCompatibilitySpan.dylib",
    ],
    data = ["//FragSeal:fragseal_backdeploy_bundle"],
    target_compatible_with = ["@platforms//os:macos"],
)
