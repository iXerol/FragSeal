load("@gazelle//:def.bzl", "gazelle", "gazelle_binary")

# Ignore the `.build` folder that is created by running Swift package manager
# commands. The Swift Gazelle plugin executes some Swift package manager
# commands to resolve external dependencies. This results in a `.build` file
# being created.
# NOTE: Swift package manager is not used to build any of the external packages.
# The `.build` directory should be ignored. Be sure to configure your source
# control to ignore it (i.e., add it to your `.gitignore`).
# gazelle:exclude .build

# This declaration builds a Gazelle binary that incorporates all of the Gazelle
# plugins for the languages that you use in your workspace. In this example, we
# are only listing the Gazelle plugin for Swift from rules_swift_package_manager.
gazelle_binary(
    name = "gazelle_bin",
    languages = [
        "@rules_swift_package_manager//gazelle",
    ],
)

# This target updates the Bazel build files for your project. Run this target
# whenever you add or remove source files from your project.
gazelle(
    name = "update_build_files",
    gazelle = ":gazelle_bin",
)

load("@rules_xcodeproj//xcodeproj:defs.bzl", "top_level_target", "xcodeproj")

xcodeproj(
    name = "xcodeproj",
    project_name = "FragSeal",
    tags = ["manual"],
    top_level_targets = [
        top_level_target("//FragSeal:fragseal"),
        top_level_target("//FragSealCoreTests:FragSealCoreTests"),
    ],
    minimum_xcode_version = "14.0",
)
