# FragSeal

![Swift](https://img.shields.io/badge/Swift-6.2-orange)
![macOS](https://img.shields.io/badge/macOS-14.0%2B-blue)

FragSeal is a secure single-file backup CLI. It splits a file into chunks,
encrypts each chunk in the C++ cryptography layer, uploads them through an object
storage backend, and records the backup in a TOML manifest.

The public surface is intentionally storage- and backup-oriented:

- `fragseal upload`
- `fragseal download`
- `manifest.toml`

## Compatibility

| Host | Build / Run mode |
| --- | --- |
| macOS 14+ | Supported |
| macOS 26+ | Native CLI binary |
| macOS 14-25 | Backdeploy bundle |
| Linux | Build and test on a Linux host or Docker container |

## Build with Bazel

Install [Bazel](https://bazel.build) or
[Bazelisk](https://github.com/bazelbuild/bazelisk).

Common commands:

```sh
make build
make build PRODUCT=framework
make build PLATFORM=macos RUNTIME=backdeploy
make build PLATFORM=linux DECRYPTER=openssl
make test
make project
```

`make test` runs both the core test suite and a CLI artifact functional test for the
selected host/runtime.

Useful direct Bazel targets:

```sh
bazel build //FragSeal:fragseal
bazel build //FragSeal:universal_fragseal
bazel build //FragSealCore:FragSealCore
```

`make project` generates `FragSeal.xcodeproj`.

## Runtime requirements

- OpenSSL is required for modern crypto modes and PBKDF2 key derivation.
- On Apple platforms, `CommonCrypto` is retained only for legacy
  `aes-128-cbc` restore compatibility.
- Linux builds also require `libxml2` headers for the AWS/Smithy XML stack.
- For S3 uploads/downloads, standard AWS credential resolution is used.
- For non-interactive runs, set `FRAGSEAL_PASSPHRASE`.

Linux packages:

```sh
sudo apt-get install -y libssl-dev libxml2-dev pkg-config clang lldb lld
```

If the OpenSSL runtime library is in a non-standard location, provide:

```sh
OPENSSL_LIB=/absolute/path/to/libcrypto make test DECRYPTER=openssl
```

## Usage

```text
USAGE: fragseal <subcommand>

SUBCOMMANDS:
  upload      Encrypt, chunk, and upload a file
  download    Restore a file from a TOML manifest
```

Upload to local storage:

```sh
fragseal upload \
  --input archive.bin \
  --manifest backup.toml \
  --storage-uri file:///tmp/fragseal
```

Upload to S3:

```sh
fragseal upload \
  --input archive.bin \
  --manifest backup.toml \
  --storage-uri s3://my-bucket/backups \
  --region us-east-1 \
  --algorithm aes-256-gcm
```

Restore:

```sh
fragseal download \
  --manifest backup.toml \
  --output restored.bin
```

Passphrase input:

- Interactive TTY: prompt securely
- Non-interactive: `FRAGSEAL_PASSPHRASE=...`

## Manifest format

FragSeal writes TOML manifests with storage, encryption, and chunk metadata.
`nonce`/`iv` live in the manifest, not in chunk payload prefixes.

```toml
version = 1

[backup]
id = "uuid"
source_name = "archive.bin"
created_at = "2026-03-07T12:00:00Z"
chunk_size = 67108864
original_size = 123456789
original_sha256 = "hex"

[storage]
backend = "s3"
bucket = "my-bucket"
region = "us-east-1"
prefix = "backups/<backup-id>"

[encryption]
mode = "aes-256-gcm"
kdf = "pbkdf2-sha256"
salt = "base64"
iterations = 600000
wrapped_key = "base64"

[[chunks]]
index = 0
object_key = "backups/<backup-id>/chunks/00000000.bin"
offset = 0
plaintext_size = 67108864
ciphertext_size = 67108880
sha256 = "hex"
nonce = "base64"
```

Supported encryption modes:

- `aes-256-gcm` (default for new uploads)
- `chacha20-poly1305`
- `legacy-aes-128-cbc` (read-only restore compatibility)

## Test fixtures

Framework tests use deterministic backup fixtures under
`FragSealCoreTests/Resources`.

Generate or refresh them with:

```sh
make resources
```

The fixture generator now creates:

- `legacy_plaintext.bin`
- `legacy_chunk_0.bin`
- `legacy_chunk_1.bin`

These fixtures are used for legacy restore compatibility tests only.

## Test matrix

Host-native commands:

```sh
make test
make build PRODUCT=cli PLATFORM=macos RUNTIME=backdeploy
make build PRODUCT=cli PLATFORM=linux
```

On macOS, Linux validation can be run through Docker:

```sh
docker compose run --rm --entrypoint /bin/bash swift-linux -lc 'make build PLATFORM=linux'
docker compose run --rm --entrypoint /bin/bash swift-linux -lc 'make test PLATFORM=linux'
```

If the repo is mounted as a linked Git worktree, copy it to a temp directory
inside the container before running Bazel so the `.git` indirection stays valid.

## VS Code setup (bis)

This project uses [bis](https://github.com/buildbuddy-io/bis) as a dev
dependency for VS Code / SourceKit-LSP integration.

### Compile commands

Generate (or refresh) `compile_commands.json` for Go-to-definition, hover
docs, and the **Show Swift Interface for Clang Header** task:

```sh
bazel run //.bis:refresh_compile_commands
```

Re-run this whenever you add or change Bazel targets.

### Debugger

`launch.json` is not tracked because the binary path is architecture-specific.
Create `.vscode/launch.json` with the path that matches your host:

```json
{
    "configurations": [
        {
            "debuggerRoot": "${workspaceFolder}",
            "name": "Launch",
            "preLaunchTask": "${config:bis.pre_launch_task_name}",
            "program": "${workspaceFolder}/bazel-out/<cpu>-fastbuild/bin/FragSeal/fragseal",
            "request": "launch",
            "sourcePath": "${workspaceFolder}",
            "type": "lldb-dap"
        },
        {
            "debuggerRoot": "${workspaceFolder}",
            "name": "Attach",
            "program": "${workspaceFolder}/bazel-out/<cpu>-fastbuild/bin/FragSeal/fragseal",
            "request": "attach",
            "sourcePath": "${workspaceFolder}",
            "type": "lldb-dap"
        }
    ],
    "version": "2.0.0"
}
```

Replace `<cpu>` with your host CPU string. You can find it by running:

```sh
bazel build //FragSeal:fragseal && ls bazel-out/ | grep fastbuild
```

Common values: `darwin_arm64`, `darwin_x86_64`, `k8`.

### Show Swift Interface for Clang Header

Mixed C++/Swift modules expose their C++ API to Swift via Clang modules. The
**Show Swift Interface for Clang Header** task synthesizes the Swift view of a
given `.hpp` header — useful for checking argument labels, type mappings, and
`Span<T>` wrappers generated by `SafeInteropWrappers`.

**Usage:**

1. Open any `.hpp` file from an `include/` directory.
2. Run **Tasks: Run Task → Show Swift Interface for Clang Header**
   (`⇧⌘P` → `Tasks: Run Task`).
3. The synthesized interface opens in a new editor tab as
   `/tmp/<header>.swiftinterface`.

`compile_commands.json` must be up to date (see [Compile commands](#compile-commands) above).
The script reads it to find which Clang module owns the header and what
compiler flags to pass to `swift-synthesize-interface`.

## Backdeploy note

On macOS earlier than 26, run the backdeploy bundle produced by:

```sh
make build PLATFORM=macos RUNTIME=backdeploy
./bazel-bin/FragSeal/fragseal_backdeploy
```

Do not run the native `fragseal` binary directly on macOS 14-15.
