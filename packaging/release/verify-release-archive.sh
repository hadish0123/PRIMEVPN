#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &&
    pwd
)"
REPO_ROOT="$(
    cd "$SCRIPT_DIR/../.." &&
    pwd
)"

ARCHIVE="${1:-$REPO_ROOT/release-out/primevpn-linux-amd64.tar.gz}"
SHA_FILE="${2:-$ARCHIVE.sha256}"
EXPECTED_VERSION="${3:-$(tr -d '[:space:]' < "$REPO_ROOT/internal/config/version")}"
EXPECTED_SOURCE_HEAD="${4:-}"

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

need() {
    command -v "$1" >/dev/null 2>&1 ||
        fail "missing required tool: $1"
}

for tool in tar sha256sum file grep awk find mktemp; do
    need "$tool"
done

test -f "$ARCHIVE" || fail "release archive not found: $ARCHIVE"
test -f "$SHA_FILE" || fail "release checksum file not found: $SHA_FILE"
test "$(basename "$ARCHIVE")" = "primevpn-linux-amd64.tar.gz" ||
    fail "unexpected archive name: $(basename "$ARCHIVE")"

ARCHIVE_DIR="$(cd -- "$(dirname -- "$ARCHIVE")" && pwd)"
SHA_BASE="$(basename "$SHA_FILE")"

(
    cd "$ARCHIVE_DIR"
    sha256sum -c "$SHA_BASE"
)

LISTING="$(mktemp)"
WORK="$(mktemp -d)"
trap 'rm -f "$LISTING"; rm -rf "$WORK"' EXIT

tar -tzf "$ARCHIVE" > "$LISTING"

grep -q '^primevpn/$' "$LISTING" ||
    fail "archive root directory must be primevpn/"

if grep -Eq '(^/|(^|/)\.\.(/|$))' "$LISTING"; then
    fail "archive contains an unsafe path"
fi

if grep -Ev '^primevpn(/|$)' "$LISTING" | grep -q .; then
    fail "archive contains files outside primevpn/"
fi

tar -xzf "$ARCHIVE" -C "$WORK"

ROOT="$WORK/primevpn"
REQUIRED_PATHS=(
    primevpn
    primevpn.sh
    primevpn.rc
    y-ui.sh
    y-ui-migration-center.py
    primevpn.service.debian
    primevpn.service.arch
    primevpn.service.rhel
    LICENSE
    RELEASE_VERSION
    RELEASE_MANIFEST
    RUNTIME_SOURCES
    SHA256SUMS
    bin/xray-linux-amd64
    bin/mtg-linux-amd64
    bin/geoip.dat
    bin/geosite.dat
    bin/geoip_IR.dat
    bin/geosite_IR.dat
    bin/geoip_RU.dat
    bin/geosite_RU.dat
    sub_templates/ourenus/index.html
    sub_templates/ourenus/index.php
)

for path in "${REQUIRED_PATHS[@]}"; do
    test -f "$ROOT/$path" ||
        fail "archive required file missing: primevpn/$path"
done

test -x "$ROOT/primevpn" || fail "panel binary is not executable"
test -x "$ROOT/primevpn.sh" || fail "management script is not executable"
test -x "$ROOT/primevpn.rc" || fail "OpenRC script is not executable"
test -x "$ROOT/bin/xray-linux-amd64" || fail "custom Xray binary is not executable"
test -x "$ROOT/bin/mtg-linux-amd64" || fail "mtg binary is not executable"

if find "$ROOT" -type l -print -quit | grep -q .; then
    fail "release archive contains symlinks"
fi

ACTUAL_VERSION="$(tr -d '[:space:]' < "$ROOT/RELEASE_VERSION")"
test "$ACTUAL_VERSION" = "$EXPECTED_VERSION" ||
    fail "archive version mismatch: got $ACTUAL_VERSION expected $EXPECTED_VERSION"

manifest_value() {
    local key="$1"
    awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' "$ROOT/RELEASE_MANIFEST"
}

MANIFEST_VERSION="$(manifest_value VERSION)"
MANIFEST_ARCH="$(manifest_value ARCH)"
MANIFEST_HEAD="$(manifest_value SOURCE_HEAD)"
MANIFEST_PANEL_SHA="$(manifest_value PANEL_SHA256)"
MANIFEST_XRAY_SHA="$(manifest_value CUSTOM_XRAY_SHA256)"
MANIFEST_RUNTIME_SHA="$(manifest_value RUNTIME_SOURCES_SHA256)"

test "$MANIFEST_VERSION" = "$EXPECTED_VERSION" ||
    fail "manifest VERSION mismatch"
test "$MANIFEST_ARCH" = "linux-amd64" ||
    fail "manifest ARCH must be linux-amd64"
test -n "$MANIFEST_HEAD" || fail "manifest SOURCE_HEAD is missing"
test -n "$MANIFEST_PANEL_SHA" || fail "manifest PANEL_SHA256 is missing"
test -n "$MANIFEST_XRAY_SHA" || fail "manifest CUSTOM_XRAY_SHA256 is missing"
test -n "$MANIFEST_RUNTIME_SHA" || fail "manifest RUNTIME_SOURCES_SHA256 is missing"

if [[ -n "$EXPECTED_SOURCE_HEAD" ]]; then
    test "$MANIFEST_HEAD" = "$EXPECTED_SOURCE_HEAD" ||
        fail "manifest SOURCE_HEAD mismatch: got $MANIFEST_HEAD expected $EXPECTED_SOURCE_HEAD"
fi

ACTUAL_PANEL_SHA="$(sha256sum "$ROOT/primevpn" | awk '{print $1}')"
ACTUAL_XRAY_SHA="$(sha256sum "$ROOT/bin/xray-linux-amd64" | awk '{print $1}')"
ACTUAL_RUNTIME_SHA="$(sha256sum "$ROOT/RUNTIME_SOURCES" | awk '{print $1}')"

test "$ACTUAL_PANEL_SHA" = "$MANIFEST_PANEL_SHA" ||
    fail "panel SHA256 does not match RELEASE_MANIFEST"
test "$ACTUAL_XRAY_SHA" = "$MANIFEST_XRAY_SHA" ||
    fail "custom Xray SHA256 does not match RELEASE_MANIFEST"
test "$ACTUAL_RUNTIME_SHA" = "$MANIFEST_RUNTIME_SHA" ||
    fail "runtime source manifest SHA256 does not match RELEASE_MANIFEST"

file "$ROOT/bin/xray-linux-amd64" | grep -q 'statically linked' ||
    fail "custom Xray binary is not statically linked"

(
    cd "$ROOT"
    sha256sum -c SHA256SUMS
)

grep -q '^WorkingDirectory=/usr/local/primevpn/$' "$ROOT/primevpn.service.debian" ||
    fail "Debian service WorkingDirectory is not canonical"
grep -q '^ExecStart=/usr/local/primevpn/primevpn$' "$ROOT/primevpn.service.debian" ||
    fail "Debian service ExecStart is not canonical"
grep -q '^EnvironmentFile=-/etc/default/primevpn$' "$ROOT/primevpn.service.debian" ||
    fail "Debian service EnvironmentFile is not canonical"

grep -q '^WorkingDirectory=/usr/local/primevpn/$' "$ROOT/primevpn.service.arch" ||
    fail "Arch service WorkingDirectory is not canonical"
grep -q '^ExecStart=/usr/local/primevpn/primevpn$' "$ROOT/primevpn.service.arch" ||
    fail "Arch service ExecStart is not canonical"
grep -q '^EnvironmentFile=-/etc/conf.d/primevpn$' "$ROOT/primevpn.service.arch" ||
    fail "Arch service EnvironmentFile is not canonical"

grep -q '^WorkingDirectory=/usr/local/primevpn/$' "$ROOT/primevpn.service.rhel" ||
    fail "RHEL service WorkingDirectory is not canonical"
grep -q '^ExecStart=/usr/local/primevpn/primevpn$' "$ROOT/primevpn.service.rhel" ||
    fail "RHEL service ExecStart is not canonical"
grep -q '^EnvironmentFile=-/etc/sysconfig/primevpn$' "$ROOT/primevpn.service.rhel" ||
    fail "RHEL service EnvironmentFile is not canonical"

printf 'RELEASE_VERIFY=pass\n'
printf 'VERSION=%s\n' "$ACTUAL_VERSION"
printf 'SOURCE_HEAD=%s\n' "$MANIFEST_HEAD"
printf 'PANEL_SHA256=%s\n' "$ACTUAL_PANEL_SHA"
printf 'CUSTOM_XRAY_SHA256=%s\n' "$ACTUAL_XRAY_SHA"
printf 'RUNTIME_SOURCES_SHA256=%s\n' "$ACTUAL_RUNTIME_SHA"
printf 'ARCHIVE_SHA256=%s\n' "$(sha256sum "$ARCHIVE" | awk '{print $1}')"
