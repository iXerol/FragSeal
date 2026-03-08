#!/usr/bin/env bash

set -euo pipefail

mode="$1"
binary_runfile="$2"
dylib_runfile="${3:-}"

resolve_runfile() {
    local runfile_path="$1"
    local workspace_path="$runfile_path"

    if [[ "$runfile_path" != "${TEST_WORKSPACE}/"* ]]; then
        workspace_path="${TEST_WORKSPACE}/${runfile_path}"
    fi

    if [[ -n "${RUNFILES_MANIFEST_FILE:-}" ]]; then
        awk -v runfile="$runfile_path" '
            $1 == runfile {
                $1 = ""
                sub(/^ /, "")
                print
                exit
            }
        ' "$RUNFILES_MANIFEST_FILE"
        awk -v runfile="$workspace_path" '
            $1 == runfile {
                $1 = ""
                sub(/^ /, "")
                print
                exit
            }
        ' "$RUNFILES_MANIFEST_FILE"
        return
    fi

    local runfiles_dir="${RUNFILES_DIR:-${TEST_SRCDIR:-}}"
    if [[ -n "$runfiles_dir" ]]; then
        if [[ -f "$runfiles_dir/$runfile_path" ]]; then
            printf '%s\n' "$runfiles_dir/$runfile_path"
        else
            printf '%s\n' "$runfiles_dir/$workspace_path"
        fi
    fi
}

create_input_file() {
    local output_path="$1"
    : >"$output_path"
    local index
    for index in $(seq 0 255); do
        printf 'fragseal-chunk-%03d\n' "$index" >>"$output_path"
    done
}

run_round_trip() {
    local binary_path="$1"
    local test_name="$2"
    local algorithm="$3"
    local expected_mode="$4"
    local test_root="$TEST_TMPDIR/$test_name"
    local storage_root="$test_root/storage"
    local input_path="$test_root/input.txt"
    local manifest_path="$test_root/manifest.toml"
    local output_path="$test_root/output.txt"
    local remote_manifest_path
    local chunk_count

    rm -rf "$test_root"
    mkdir -p "$storage_root"
    create_input_file "$input_path"

    export FRAGSEAL_PASSPHRASE="fragseal-passphrase"

    local upload_args=(
        upload
        --input "$input_path"
        --manifest "$manifest_path"
        --storage-uri "file://$storage_root"
        --chunk-size 1024
    )
    if [[ -n "$algorithm" ]]; then
        upload_args+=(--algorithm "$algorithm")
    fi

    "$binary_path" --help >/dev/null
    "$binary_path" "${upload_args[@]}" >/dev/null

    [[ -f "$manifest_path" ]]
    grep -Eq "mode = ['\"]$expected_mode['\"]" "$manifest_path"

    remote_manifest_path="$(find "$storage_root" -path '*/manifest.toml' -type f | head -n 1)"
    if [[ -z "$remote_manifest_path" ]]; then
        echo "Remote manifest copy was not uploaded." >&2
        exit 1
    fi
    cmp -s "$manifest_path" "$remote_manifest_path"

    chunk_count="$(find "$storage_root" -path '*/chunks/*.bin' -type f | wc -l | tr -d ' ')"
    if [[ "$chunk_count" -lt 2 ]]; then
        echo "Expected multiple chunk uploads, found $chunk_count." >&2
        exit 1
    fi

    "$binary_path" download --manifest "$manifest_path" --output "$output_path" >/dev/null
    cmp -s "$input_path" "$output_path"
}

main() {
    local binary_path
    binary_path="$(resolve_runfile "$binary_runfile")"
    if [[ -z "$binary_path" || ! -f "$binary_path" ]]; then
        echo "Unable to locate CLI artifact '$binary_runfile' in runfiles." >&2
        exit 1
    fi

    local runnable_path="$binary_path"
    if [[ "$mode" == "backdeploy" ]]; then
        local dylib_path
        dylib_path="$(resolve_runfile "$dylib_runfile")"
        if [[ -z "$dylib_path" || ! -f "$dylib_path" ]]; then
            echo "Unable to locate '$dylib_runfile' in runfiles." >&2
            exit 1
        fi

        local runtime_root="$TEST_TMPDIR/runtime"
        rm -rf "$runtime_root"
        mkdir -p "$runtime_root/Frameworks"
        cp "$binary_path" "$runtime_root/fragseal_backdeploy"
        cp "$dylib_path" "$runtime_root/Frameworks/libswiftCompatibilitySpan.dylib"
        chmod +x "$runtime_root/fragseal_backdeploy"
        runnable_path="$runtime_root/fragseal_backdeploy"
    fi

    run_round_trip "$runnable_path" "default-round-trip" "" "aes-256-gcm"
    run_round_trip "$runnable_path" "chacha-round-trip" "chacha20-poly1305" "chacha20-poly1305"
}

main "$@"
