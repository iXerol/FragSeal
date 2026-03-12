#version 0.5.2
load("@bis//:refresh_compile_commands.bzl", "refresh_compile_commands")
load("@bis//:refresh_launch_json.bzl", "refresh_launch_json")
refresh_compile_commands(
  name = "refresh_compile_commands",
  targets = [
    "//FragSealCore:FragSealCore"
  ],
  exclude_headers = "all",
  optionals = "",
  tags = ["manual"],
)

refresh_launch_json(
  name = "refresh_launch_json",
  target = "//FragSeal:fragseal",
  tags = ["manual"],
)

