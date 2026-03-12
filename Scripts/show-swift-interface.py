#!/usr/bin/env python3
"""Show the synthesized Swift interface for a Clang header.

Usage: show-swift-interface.py <header-file>

Creates a temporary single-header module and runs swift-synthesize-interface
to show only the Swift API exposed by that specific file.
Falls back to the full containing module if the header is not self-contained.
"""

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path


def load_compile_commands(workspace: str) -> list:
    path = os.path.join(workspace, "compile_commands.json")
    with open(path) as f:
        return json.load(f)


def collect_modulemap_paths(compile_commands: list) -> set[str]:
    """Collect all -fmodule-map-file paths referenced in compile_commands."""
    paths = set()
    for entry in compile_commands:
        args = entry.get("arguments", [])
        for i, arg in enumerate(args):
            if arg == "-fmodule-map-file" and i + 1 < len(args):
                paths.add(args[i + 1])
            elif arg.startswith("-fmodule-map-file="):
                paths.add(arg[len("-fmodule-map-file="):])
    return paths


def find_containing_module(header_path: str, modulemap_paths: set[str], workspace: str):
    """Return (module_name, modulemap_abs) for the module containing the header.

    Strategy:
    1. Exact match: header is directly listed in a modulemap.
    2. Directory fallback: a modulemap in the same include directory.
    """
    header_abs = str(Path(os.path.join(workspace, header_path)).resolve())
    header_dir = os.path.dirname(header_abs)
    fallback = None

    for mmap_path in modulemap_paths:
        mmap_abs = mmap_path if os.path.isabs(mmap_path) else os.path.join(workspace, mmap_path)
        if not os.path.exists(mmap_abs):
            continue
        with open(mmap_abs) as f:
            content = f.read()

        mmap_dir = os.path.dirname(mmap_abs)
        module_name = None
        for line in content.splitlines():
            line = line.strip()
            if line.startswith("module ") and '"' in line:
                module_name = line.split('"')[1]
                break
        if not module_name:
            continue

        for line in content.splitlines():
            line = line.strip()
            if not line.startswith("header ") or '"' not in line:
                continue
            parts = line.split('"')
            if len(parts) < 2:
                continue
            candidate = os.path.normpath(os.path.join(mmap_dir, parts[1]))
            if candidate == header_abs:
                return module_name, mmap_abs
            if fallback is None and os.path.dirname(candidate) == header_dir:
                fallback = (module_name, mmap_abs)

    return fallback if fallback else (None, None)


def find_args_for_modulemap(modulemap_abs: str, compile_commands: list, workspace: str):
    """Find compile arguments from a Swift entry that references the given modulemap."""
    for entry in compile_commands:
        args = entry.get("arguments", [])
        entry_dir = entry.get("directory", workspace)
        for i, arg in enumerate(args):
            if arg.startswith("-fmodule-map-file="):
                raw = arg[len("-fmodule-map-file="):]
            elif arg == "-fmodule-map-file" and i + 1 < len(args):
                raw = args[i + 1]
            else:
                continue
            candidate = raw if os.path.isabs(raw) else os.path.normpath(os.path.join(entry_dir, raw))
            if candidate == modulemap_abs:
                return args, entry_dir
    return None, None


def build_synthesize_command(module_name: str, compile_args: list, extra_modulemap: str | None = None) -> list:
    try:
        tool = subprocess.check_output(
            ["xcrun", "--find", "swift-synthesize-interface"],
            stderr=subprocess.DEVNULL,
        ).decode().strip()
    except Exception:
        tool = "swift-synthesize-interface"

    cmd = [tool, "-module-name", module_name]

    i = 1  # skip argv[0] ("swiftc")
    while i < len(compile_args):
        arg = compile_args[i]

        if arg in ("-target", "-sdk") and i + 1 < len(compile_args):
            cmd += [arg, compile_args[i + 1]]
            i += 2
            continue

        if arg.startswith("-I") or arg.startswith("-F"):
            cmd.append(arg)
            i += 1
            continue

        if arg in ("-I", "-F") and i + 1 < len(compile_args):
            cmd += [arg, compile_args[i + 1]]
            i += 2
            continue

        if arg.startswith("-cxx-interoperability-mode="):
            cmd.append(arg)
            i += 1
            continue

        if arg == "-Xcc" and i + 1 < len(compile_args):
            cmd += ["-Xcc", compile_args[i + 1]]
            i += 2
            continue

        if arg.startswith("-fmodule-map-file="):
            cmd += ["-Xcc", arg]
            i += 1
            continue

        if arg == "-fmodule-map-file" and i + 1 < len(compile_args):
            cmd += ["-Xcc", f"-fmodule-map-file={compile_args[i + 1]}"]
            i += 2
            continue

        i += 1

    if extra_modulemap:
        cmd += ["-Xcc", f"-fmodule-map-file={extra_modulemap}"]

    return cmd


def try_single_header(header_abs: str, module_name: str, compile_args: list, workspace: str) -> str | None:
    """Try synthesizing interface for a single header via a temporary modulemap.
    Returns the output string, or None if it fails."""
    temp_module = f"_SwiftInterfacePreview_{Path(header_abs).stem}"
    modulemap_content = f'module "{temp_module}" {{\n    export *\n    header "{header_abs}"\n}}\n'

    with tempfile.TemporaryDirectory() as tmpdir:
        mmap_path = os.path.join(tmpdir, "module.modulemap")
        with open(mmap_path, "w") as f:
            f.write(modulemap_content)

        cmd = build_synthesize_command(temp_module, compile_args, extra_modulemap=mmap_path)
        result = subprocess.run(cmd, capture_output=True, text=True, cwd=workspace)

        if result.returncode == 0 and result.stdout.strip():
            return result.stdout
        return None


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <header-file>", file=sys.stderr)
        sys.exit(1)

    header_path = sys.argv[1]
    workspace = os.getcwd()

    try:
        compile_commands = load_compile_commands(workspace)
    except FileNotFoundError:
        print("compile_commands.json not found. Run: bazel run //.bis:refresh_compile_commands", file=sys.stderr)
        sys.exit(1)

    modulemap_paths = collect_modulemap_paths(compile_commands)
    module_name, modulemap_abs = find_containing_module(header_path, modulemap_paths, workspace)

    if not module_name:
        print(f"No Swift module found for: {header_path}", file=sys.stderr)
        print("The header may not be exposed via a Bazel Clang module.", file=sys.stderr)
        sys.exit(1)

    compile_args, _ = find_args_for_modulemap(modulemap_abs, compile_commands, workspace)
    if not compile_args:
        print(f"No compile args found for module: {module_name}", file=sys.stderr)
        sys.exit(1)

    header_abs = str(Path(os.path.join(workspace, header_path)).resolve())

    # Try single-header mode first
    output = try_single_header(header_abs, module_name, compile_args, workspace)
    if output:
        print(f"// Swift interface for: {os.path.basename(header_path)}", file=sys.stderr)
        print(output)
        return

    # Fallback: full module
    print(
        f"// {os.path.basename(header_path)} is not self-contained; showing full module '{module_name}'",
        file=sys.stderr,
    )
    cmd = build_synthesize_command(module_name, compile_args)
    result = subprocess.run(cmd, capture_output=True, text=True, cwd=workspace)
    if result.stdout:
        print(result.stdout)
    if result.returncode != 0:
        print(result.stderr, file=sys.stderr)
        sys.exit(result.returncode)


if __name__ == "__main__":
    main()
