#!/bin/sh
# Build the standalone ICU engine matching pinned R base collation (separate from stringi).
# All work stays in the foreground; no R/stringi library is loaded at runtime.
set -eu
ICU_HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ICU_PREFIX=${1:-"$ICU_HERE/.native/icu-76.1"}
ICU_JOBS=${CL_TIDYR_ICU_JOBS:-4}
ICU_URL=https://github.com/unicode-org/icu/releases/download/release-76-1/icu4c-76_1-src.tgz
ICU_SHA256=dfacb46bfe4747410472ce3e1144bf28a102feeaa4e3875bac9b4c6cf30f4f3e
ICU_BUILD=$(mktemp -d "${TMPDIR:-/tmp}/cl-tidyr-icu76.XXXXXX")
trap 'rm -rf "$ICU_BUILD"' EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
ICU_ARCHIVE="$ICU_BUILD/icu4c-76_1-src.tgz"
if [ -n "${CL_TIDYR_ICU_TARBALL:-}" ]; then
  cp "$CL_TIDYR_ICU_TARBALL" "$ICU_ARCHIVE"
else
  curl -fL --retry 2 -o "$ICU_ARCHIVE" "$ICU_URL"
fi
if command -v sha256sum >/dev/null 2>&1; then
  ICU_ACTUAL=$(sha256sum "$ICU_ARCHIVE" | cut -d ' ' -f 1)
else
  ICU_ACTUAL=$(shasum -a 256 "$ICU_ARCHIVE" | cut -d ' ' -f 1)
fi
[ "$ICU_ACTUAL" = "$ICU_SHA256" ] || { echo "ICU source checksum mismatch" >&2; exit 1; }
tar -xzf "$ICU_ARCHIVE" -C "$ICU_BUILD"
cd "$ICU_BUILD/icu/source"
# Host environment flags can accidentally select an incompatible installed ICU.
ICU_LDFLAGS=
if [ "$(uname -s)" = Darwin ]; then ICU_LDFLAGS=-Wl,-headerpad_max_install_names; fi
env CPPFLAGS= CFLAGS= CXXFLAGS= LDFLAGS="$ICU_LDFLAGS" ./configure --prefix="$ICU_PREFIX" \
  --disable-tests --disable-samples --disable-static --enable-shared
if command -v gmake >/dev/null 2>&1; then ICU_MAKE=gmake; else ICU_MAKE=make; fi
"$ICU_MAKE" -j "$ICU_JOBS"
"$ICU_MAKE" install
# ICU76's Darwin install names are relative; use relocatable sibling dylibs.
if [ "$(uname -s)" = Darwin ]; then
  for file in "$ICU_PREFIX"/lib/*.76.1.dylib; do
    base=$(basename "$file")
    install_name_tool -id "@rpath/$base" "$file"
    for dep in libicudata.76.dylib libicuuc.76.dylib libicui18n.76.dylib libicuio.76.dylib libicutu.76.dylib libicutest.76.dylib; do
      install_name_tool -change "$dep" "@loader_path/$dep" "$file"
    done
    codesign --force --sign - "$file"
  done
fi
printf '%s\n' "$ICU_SHA256" > "$ICU_PREFIX/.source-sha256"
printf 'ICU 76.1 installed in %s\n' "$ICU_PREFIX"
