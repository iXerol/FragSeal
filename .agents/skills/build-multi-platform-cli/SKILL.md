---
name: build-multi-platform-cli
description: Build and troubleshoot FragSeal on macOS/Linux with the supported crypto backends, validating framework tests and CLI functional tests. On macOS, also validate Linux via Docker.
---

# Build And Test (Multi-Platform)

Use this when touching Bazel files, toolchains, Docker, crypto backend wiring, or CLI packaging.

## Workflow

1. Detect host OS and macOS major version when relevant.
   - `sw_vers -productVersion || true`
   - `uname -s`

2. Validate the host matrix.
   - macOS:
     - `make test DECRYPTER=commoncrypto`
     - `make test DECRYPTER=openssl`
     - `make build PRODUCT=cli PLATFORM=macos RUNTIME=backdeploy`
     - `make build PRODUCT=cli PLATFORM=macos RUNTIME=native`
   - Linux:
     - `make test PLATFORM=linux DECRYPTER=openssl`
     - `make build PRODUCT=cli PLATFORM=linux DECRYPTER=openssl`

3. On macOS, validate Linux through Docker when available.
   - The compose service mounts the repo at `/workspace`.
   - If the repo is a linked worktree, copy it to a temp directory inside the container before running Bazel because `.git` points outside the mount.
   - Preferred command:
     - `docker compose run --rm --entrypoint /bin/bash swift-linux -lc 'rm -rf /tmp/fragseal && mkdir -p /tmp/fragseal && tar -C /workspace -cf - . | tar -C /tmp/fragseal -xf - && cd /tmp/fragseal && make build PLATFORM=linux DECRYPTER=openssl && make test PLATFORM=linux DECRYPTER=openssl'`

4. If any command fails, fix the first real error and rerun that exact command before continuing.

## Notes

- `make test` covers both Swift tests and CLI functional tests for the selected host/runtime.
- `DECRYPTER=commoncrypto` is macOS-only and is retained for legacy AES-128-CBC restore validation.
- `DECRYPTER=openssl` is required for modern crypto modes and all Linux validation.
- On macOS 14-15, the runtime test path is the backdeploy bundle; on macOS 26+, `make test` will select the native test path automatically.
