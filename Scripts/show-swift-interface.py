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
            stripped = line.strip()
            if stripped.startswith("module ") and "{" in stripped:
                # Module name may be quoted ("Name") or unquoted (Name)
                name_part = stripped[len("module "):].split("{")[0].strip()
                if name_part.startswith('"'):
                    module_name = name_part.split('"')[1]
                elif name_part:
                    module_name = name_part
                break
        if not module_name:
            continue

        for line in content.splitlines():
            stripped = line.strip()
            if not stripped.startswith("header ") or '"' not in stripped:
                continue
            parts = stripped.split('"')
            if len(parts) < 2:
                continue
            # Header paths are relative to the modulemap's directory
            candidate = os.path.normpath(os.path.join(mmap_dir, parts[1]))
            if candidate == header_abs:
                return module_name, mmap_abs
            if fallback is None and os.path.dirname(candidate) == header_dir:
                fallback = (module_name, mmap_abs)

    return fallback if fallback else (None, None)


def find_submodule_name(header_abs: str, modulemap_abs: str) -> str | None:
    """Return the submodule name if the header appears as a named submodule in the modulemap."""
    if not os.path.exists(modulemap_abs):
        return None
    with open(modulemap_abs) as f:
        content = f.read()

    mmap_dir = os.path.dirname(modulemap_abs)
    current_submodule = None
    depth = 0
    for line in content.splitlines():
        stripped = line.strip()
        opens = stripped.count("{")
        closes = stripped.count("}")
        # Match both "explicit module X {" and "module X {" at sub-level (depth == 0 means top-level)
        if depth == 0 and stripped.startswith("module ") and opens > 0:
            # Top-level module — just track depth
            depth += opens - closes
        elif depth == 1 and stripped.startswith(("module ", "explicit module ")) and opens > 0:
            parts = stripped.lstrip("explicit ").split()
            if len(parts) >= 2:
                current_submodule = parts[1].split("{")[0].strip()
            depth += opens - closes
        elif depth > 1:
            depth += opens - closes
            if stripped.startswith("header ") and '"' in stripped:
                hdr_path = stripped.split('"')[1]
                candidate = os.path.normpath(
                    hdr_path if os.path.isabs(hdr_path) else os.path.join(mmap_dir, hdr_path)
                )
                if candidate == header_abs:
                    return current_submodule
            if depth <= 1:
                current_submodule = None
        else:
            depth += opens - closes

    return None


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

    # Try submodule mode: if the modulemap explicitly defines a submodule for this header,
    # use Parent.SubModule naming (no temp modulemap needed, cross-references work correctly).
    submodule_name = find_submodule_name(header_abs, modulemap_abs)
    if submodule_name:
        qualified_name = f"{module_name}.{submodule_name}"
        print(f"// Swift interface for: {os.path.basename(header_path)} (submodule {qualified_name})", file=sys.stderr)
        cmd = build_synthesize_command(qualified_name, compile_args)
        result = subprocess.run(cmd, capture_output=True, text=True, cwd=workspace)
        if result.returncode == 0 and result.stdout.strip():
            print(result.stdout)
            return
        # Submodule synthesis failed — fall through to single-header mode

    # Try single-header mode
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
