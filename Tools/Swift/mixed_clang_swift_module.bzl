load("@rules_cc//cc:defs.bzl", "cc_library")
load("@rules_swift//swift:swift.bzl", "swift_library")
load("@rules_swift//swift:swift_interop_hint.bzl", "swift_interop_hint")
load("//Tools/Swift:generated_header.bzl", "swift_generated_header")

"""Helpers for packaging a mixed Clang/Swift implementation as one facade module.

The public interface is defined explicitly by `hdrs`; all other headers in `srcs`
remain private implementation details. The macro generates the internal Swift
re-export shim, a public umbrella header, and the Swift generated header facade.
"""

def _generated_text_file_impl(ctx):
    output = ctx.actions.declare_file(ctx.attr.output_path)
    ctx.actions.write(output = output, content = ctx.attr.content)
    return [DefaultInfo(files = depset([output]))]

generated_text_file = rule(
    implementation = _generated_text_file_impl,
    attrs = {
        "content": attr.string(mandatory = True),
        "output_path": attr.string(mandatory = True),
    },
)

def _sanitize_module_name(value):
    result = []
    for i in range(len(value)):
        ch = value[i]
        if ch in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_":
            result.append(ch)
        else:
            result.append("_")
    return "".join(result)

def _path_extension(path):
    parts = path.rsplit(".", 1)
    if len(parts) == 1:
        return ""
    return parts[1]

def _is_header(path):
    return _path_extension(path) in ["h", "hh", "hpp", "hxx"]

def _is_swift(path):
    return _path_extension(path) == "swift"

def _is_clang_src(path):
    return _path_extension(path) in ["c", "cc", "cpp", "cxx", "m", "mm"]

def _strip_include_prefix(path, strip_include_prefix):
    if strip_include_prefix and path.startswith(strip_include_prefix + "/"):
        return path[len(strip_include_prefix) + 1:]
    return path

def _umbrella_header_content(public_headers, generated_header_path, strip_include_prefix):
    lines = ["#pragma once", ""]
    for header in sorted(public_headers):
        lines.append('#include "{}"'.format(_strip_include_prefix(header, strip_include_prefix)))
    lines.append('#include "{}"'.format(_strip_include_prefix(generated_header_path, strip_include_prefix)))
    lines.append("")
    return "\n".join(lines)

def mixed_clang_swift_module(
        *,
        name,
        srcs,
        hdrs,
        module_name = None,
        clang_module_name = None,
        generated_header_path = None,
        umbrella_header_path = None,
        copts = [],
        swift_copts = [],
        clang_header_copts = [],
        includes = [],
        deps = [],
        header_deps = [],
        aspect_hints = [],
        defines = [],
        include_prefix = None,
        strip_include_prefix = None,
        testonly = False,
        visibility = None):
    """Build a mixed Clang/Swift facade module from one source list.

    Args:
      srcs: All Swift, Clang/C++, and private header inputs for the module.
      hdrs: Public headers exported by the facade. Must be a subset of `srcs`.

    The macro keeps the internal Clang-importable target private, generates an
    `@_exported import` Swift shim for that target, and exposes a single public
    facade header that includes both `hdrs` and the generated `-Swift.h`.
    """
    if visibility == None:
        fail("mixed_clang_swift_module requires explicit visibility")

    if not srcs:
        fail("mixed_clang_swift_module requires at least one source file")
    if not hdrs:
        fail("mixed_clang_swift_module requires at least one public header in hdrs")

    module_name = module_name or _sanitize_module_name(name)
    clang_module_name = clang_module_name or "_{}__C".format(module_name)
    generated_header_path = generated_header_path or "include/{}-Swift.h".format(module_name)
    umbrella_header_path = umbrella_header_path or "include/{}.h".format(module_name)

    public_header_paths = {}
    public_headers = []
    private_headers = []
    swift_srcs = []
    clang_srcs = []
    source_paths = {}

    for header in hdrs:
        header_path = str(header)
        if not _is_header(header_path):
            fail("hdrs entry '{}' is not a header in mixed_clang_swift_module({})".format(header_path, name))
        public_header_paths[header_path] = True
        public_headers.append(header)

    for src in srcs:
        path = str(src)
        source_paths[path] = True
        if _is_swift(path):
            swift_srcs.append(src)
        elif _is_header(path):
            if path in public_header_paths:
                continue
            private_headers.append(src)
        elif _is_clang_src(path):
            clang_srcs.append(src)
        else:
            fail("Unsupported source file '{}' in mixed_clang_swift_module({})".format(path, name))

    for header_path in public_header_paths.keys():
        if header_path not in source_paths:
            fail("public header '{}' is not present in srcs for mixed_clang_swift_module({})".format(header_path, name))

    if not strip_include_prefix and all([str(header).startswith("include/") for header in public_headers]):
        strip_include_prefix = "include"
    if not include_prefix and strip_include_prefix == "include":
        include_prefix = module_name
    if not includes and strip_include_prefix == "include":
        includes = ["include"]

    for generated_path in [generated_header_path, umbrella_header_path]:
        if generated_path in source_paths:
            fail("mixed_clang_swift_module({}) generates '{}'; remove the source file or override the generated path".format(name, generated_path))

    headers_name = name + "_headers"
    interop_hint_name = name + "_swift_interop"
    exported_swift_name = name + "_exported_swift"
    swift_name = name + "_swift"
    generated_header_name = name + "_swift_public_header"
    umbrella_header_name = name + "_umbrella_header"

    swift_interop_hint(
        name = interop_hint_name,
        module_name = clang_module_name,
    )

    generated_text_file(
        name = exported_swift_name,
        output_path = "_generated/{}+Exports.swift".format(module_name),
        content = "@_exported import {}\n".format(clang_module_name),
    )

    cc_library(
        name = headers_name,
        testonly = testonly,
        hdrs = public_headers,
        copts = clang_header_copts,
        includes = includes,
        deps = header_deps,
        aspect_hints = aspect_hints + [":" + interop_hint_name],
        visibility = ["//visibility:private"],
        include_prefix = include_prefix,
        strip_include_prefix = strip_include_prefix,
    )

    swift_library(
        name = swift_name,
        testonly = testonly,
        module_name = module_name,
        srcs = [":" + exported_swift_name] + swift_srcs,
        deps = deps + [":" + headers_name],
        visibility = ["//visibility:private"],
        generates_header = True,
        copts = swift_copts,
    )

    swift_generated_header(
        name = generated_header_name,
        swift_target = ":" + swift_name,
        output_path = generated_header_path,
    )

    generated_text_file(
        name = umbrella_header_name,
        output_path = umbrella_header_path,
        content = _umbrella_header_content(
            public_headers = [str(header) for header in public_headers],
            generated_header_path = generated_header_path,
            strip_include_prefix = strip_include_prefix,
        ),
    )

    cc_library(
        name = name,
        testonly = testonly,
        srcs = clang_srcs + private_headers,
        hdrs = [":" + umbrella_header_name, ":" + generated_header_name],
        copts = copts,
        defines = defines,
        deps = deps + [":" + headers_name, ":" + swift_name],
        include_prefix = include_prefix,
        strip_include_prefix = strip_include_prefix,
        visibility = visibility,
    )
