def swift_compatibility_dylib(name):
    native.genrule(
        name = name,
        outs = ["libswiftCompatibilitySpan.dylib"],
        cmd = """
set -euo pipefail
SWIFTC="$$(/usr/bin/xcrun --find swiftc)"
RESOURCE_PATH="$$("$${SWIFTC}" -print-target-info | /usr/bin/plutil -convert xml1 -o - - | /usr/bin/plutil -extract paths.runtimeResourcePath raw -o - -)"
COMPAT_DIR="$${RESOURCE_PATH%/*}"
COMPAT_PATH="$${COMPAT_DIR}/swift-6.2/macosx/libswiftCompatibilitySpan.dylib"
if [ ! -f "$$COMPAT_PATH" ]; then
  echo "compatibility library not found: $$COMPAT_PATH" >&2
  exit 1
fi
cp "$$COMPAT_PATH" "$(@D)/libswiftCompatibilitySpan.dylib"
""",
    )
