"""Repository rule that exposes system OpenSSL headers/libs inside execroot."""

def _dirname(path):
    if not path:
        return ""
    parts = path.rsplit("/", 1)
    if len(parts) == 1:
        return ""
    return parts[0]

def _basename(path):
    if not path:
        return ""
    return path.rsplit("/", 1)[-1]

def _first_existing_path(ctx, candidates):
    for candidate in candidates:
        if ctx.path(candidate).exists:
            return candidate
    return None

def _first_existing_openssl_include_root(ctx, candidates):
    for candidate in candidates:
        if ctx.path(candidate + "/openssl").exists:
            return candidate
    return None

def _openssl_local_repository_impl(ctx):
    openssl_lib_hint = ctx.os.environ.get("OPENSSL_LIB", "").strip()
    force_no_openssl = ctx.os.environ.get("FRAGSEAL_FORCE_NO_OPENSSL", "").strip().lower()
    openssl_disabled = force_no_openssl not in ["", "0", "false", "no"]
    include_candidates = list(ctx.attr.include_candidates)
    lib_dir_candidates = list(ctx.attr.lib_candidates)
    lib_file_candidates = []

    if openssl_lib_hint and not openssl_disabled:
        hint_basename = _basename(openssl_lib_hint)
        if hint_basename:
            lib_file_candidates.append("lib/" + hint_basename)
        hint_lib_dir = _dirname(openssl_lib_hint)
        if hint_lib_dir:
            lib_dir_candidates = [hint_lib_dir] + lib_dir_candidates
        hint_root = _dirname(_dirname(openssl_lib_hint))
        if hint_root:
            include_candidates = [hint_root + "/include"] + include_candidates

    include_path = None if openssl_disabled else _first_existing_openssl_include_root(ctx, include_candidates)
    lib_path = None if openssl_disabled else _first_existing_path(ctx, lib_dir_candidates)

    if include_path:
        ctx.file("include/.keep", "")
        ctx.symlink(include_path + "/openssl", "include/openssl")
    else:
        ctx.file("include/openssl/.missing", "")

    if lib_path:
        ctx.symlink(lib_path, "lib")
    else:
        ctx.file("lib/.missing", "")

    lib_candidates = lib_file_candidates + [
        "lib/libcrypto.dylib",
        "lib/libcrypto.3.dylib",
        "lib/libcrypto.so",
        "lib/libcrypto.so.3",
        "lib/libcrypto.a",
    ]
    selected_lib = None
    if not openssl_disabled:
        for lib_candidate in lib_candidates:
            if ctx.path(lib_candidate).exists:
                selected_lib = lib_candidate
                break

    openssl_available = include_path != None and selected_lib != None

    if selected_lib and selected_lib.endswith(".a"):
        crypto_rule = """cc_import(
    name = "crypto",
    static_library = "{selected_lib}",
)
""".format(selected_lib = selected_lib)
    elif selected_lib:
        crypto_rule = """cc_import(
    name = "crypto",
    shared_library = "{selected_lib}",
)
""".format(selected_lib = selected_lib)
    else:
        crypto_rule = """cc_library(
    name = "crypto",
    linkopts = ["-lcrypto"],
)
"""

    ctx.file(
        "availability.bzl",
        "OPENSSL_AVAILABLE = %s\n" % ("True" if openssl_available else "False"),
    )

    ctx.file(
        "BUILD.bazel",
        """package(default_visibility = ["//visibility:public"])

{crypto_rule}

cc_library(
    name = "openssl_headers",
    hdrs = glob(["include/openssl/**/*.h"]),
    includes = ["include"],
)

cc_library(
    name = "openssl",
    deps = [":openssl_headers", ":crypto"],
)
""".format(crypto_rule = crypto_rule),
    )

openssl_local_repository = repository_rule(
    implementation = _openssl_local_repository_impl,
    environ = [
        "OPENSSL_LIB",
        "FRAGSEAL_FORCE_NO_OPENSSL",
    ],
    attrs = {
        "include_candidates": attr.string_list(
            default = [
                "/opt/homebrew/opt/openssl@3/include",
                "/usr/local/opt/openssl@3/include",
                "/usr/include",
            ],
        ),
        "lib_candidates": attr.string_list(
            default = [
                "/opt/homebrew/opt/openssl@3/lib",
                "/usr/local/opt/openssl@3/lib",
                "/usr/lib/x86_64-linux-gnu",
                "/usr/lib64",
                "/usr/lib",
            ],
        ),
    },
    local = True,
)
