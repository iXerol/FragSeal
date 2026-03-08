"""Repository rule that exposes system OpenSSL headers/libs inside execroot."""

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
    include_path = _first_existing_openssl_include_root(ctx, ctx.attr.include_candidates)
    lib_path = _first_existing_path(ctx, ctx.attr.lib_candidates)

    if include_path:
        ctx.file("include/.keep", "")
        ctx.symlink(include_path + "/openssl", "include/openssl")
    else:
        ctx.file("include/openssl/.missing", "")

    if lib_path:
        ctx.symlink(lib_path, "lib")
    else:
        ctx.file("lib/.missing", "")

    lib_candidates = [
        "lib/libcrypto.dylib",
        "lib/libcrypto.so",
        "lib/libcrypto.so.3",
        "lib/libcrypto.a",
    ]
    selected_lib = None
    for lib_candidate in lib_candidates:
        if ctx.path(lib_candidate).exists:
            selected_lib = lib_candidate
            break

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
