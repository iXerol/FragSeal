# AGENTS.md

## Purpose

Project-specific instructions for Codex agents working in this repo.

## Quick context

- Primary build system: Bazel (via Bazelisk recommended).
- Helper targets: `make resources`, `make build`, `make test`, `make project`.
- Swift toolchain: Linux CI expects Swift 6.2.
- If a task touches build/test commands, runtime behavior, platform support, CLI usage, or environment variables already documented in `README.md`, read `README.md` first and treat it as the current project-facing reference.

## CI overview

GitHub Actions workflow: `.github/workflows/build.yml`.

- macOS job builds with `make build PRODUCT=cli PLATFORM=macos RUNTIME=...`.
- Linux job runs `make test PLATFORM=linux` with `DECRYPTER=openssl`.

## Common checks

- Build: `bazel build //FragSeal:universal_fragseal`
- Build (workflow entrypoint): `make build`
- Tests: `make test`
- CI status: use the Codex skill `check-ci-status` in `skills/check-ci-status` (requires `gh`)

## Notes

- `make test` selects the correct test target based on macOS version.
- `make build` on macOS < 26 defaults to a back-deploy bundle output.
- `.bazelrc` includes `build --xcode_version=26`; ensure CI runners have that Xcode or adjust the config/workflow.
- If regenerating fixtures is needed, run `make resources`.
- When pushing changes that affect CI, ensure `make test` and `make build` pass locally with the relevant selectors.

## Dependency Policy

- Treat successful local `make build` / `make test` in this repo as the source of truth for Swift dependency sufficiency.
- Do not add direct Swift deps only to satisfy strict-direct-deps style review comments when the current Bazel setup already builds through transitive module availability.
- This exception does not apply to public C/C++ header surfaces: exported `hdrs` must remain self-contained and correctly declared.

## Crypto Backend Policy

- `DECRYPTER_IMPL=openssl` must always mean the OpenSSL backend on every platform (macOS and Linux).
- Do not silently remap `openssl` requests to `CommonCrypto`.
- `CommonCrypto` remains the Apple default only when `DECRYPTER_IMPL` is empty.
- If OpenSSL is requested but unavailable, fail with a clear build error instead of changing backend behavior.
