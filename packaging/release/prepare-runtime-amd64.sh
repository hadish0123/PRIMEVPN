#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

SCRIPT_DIR="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &&
    pwd
)"
REPO_ROOT="$(
    cd "$SCRIPT_DIR/../.." &&
    pwd
)"

LEGACY_RUNTIME_ARCHIVE="${1:-}"
OUTPUT_ROOT="${2:-$REPO_ROOT/runtime-release-inputs}"
BIN_DIR="$OUTPUT_ROOT/bin"

CUSTOM_XRAY_SHA256="8255dd939c34cf966cc91517b6324dd3c8d0bcf49ffac8beca049a38c46845ed"

MTG_TAG="v1.15.0"
MTG_ARCHIVE="mtg-multi-1.15.0-linux-amd64.tar.gz"
MTG_SHA256="f1f8763504753fb863a0ddff83eab19c856747289c376275c44b717f1747908e"
MTG_URL="https://github.com/MHSanaei/mtg-multi/releases/download/$MTG_TAG/$MTG_ARCHIVE"

GEO_MAIN_TAG="202609290124"
GEO_MAIN_GEOIP_SHA256="3cf2236c19063c1c80803368cca5ff589c5033129fdf9ba154230c689b81fc2a"
GEO_MAIN_GEOSITE_SHA256="a4b58274fe6bc9dcc28d12b5100a759c0de442105da5e06eb26cfcccdc3d9892"

GEO_IR_TAG="202609291052"
GEO_IR_GEOIP_SHA256="75895fb63a3fc33e1ea0c3cc37891da8419bdbfb85c405fdbe01098be3d7f259"
GEO_IR_GEOSITE_SHA256="14078016dd0a7a1141686ba658f4155d10b8e37228796e3b3211c1b0e6fb1c2b"

GEO_RU_TAG="202609291003"
GEO_RU_GEOIP_SHA256="f1139aad66d91a38763dd3ea97584b9a86b49861925f2a8b07bf7b5a5688c185"
GEO_RU_GEOSITE_SHA256="76fdbe01687a6cc7683b50c38ceea84941458e8371d215918daf555665a537cd"

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

need() {
    command -v "$1" >/dev/null 2>&1 ||
        fail "missing required tool: $1"
}

for tool in curl tar sha256sum file awk find sort mktemp install; do
    need "$tool"
done

test -n "$LEGACY_RUNTIME_ARCHIVE" ||
    fail "usage: $0 <legacy-runtime-amd64.tar.gz> [output-dir]"
test -f "$LEGACY_RUNTIME_ARCHIVE" ||
    fail "legacy runtime archive not found: $LEGACY_RUNTIME_ARCHIVE"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

rm -rf "$OUTPUT_ROOT"
mkdir -p "$BIN_DIR" "$WORK/legacy"

tar -xzf "$LEGACY_RUNTIME_ARCHIVE" -C "$WORK/legacy"

test -f "$WORK/legacy/SHA256SUMS" ||
    fail "legacy runtime SHA256SUMS missing"
(
    cd "$WORK/legacy"
    sha256sum -c SHA256SUMS
)

LEGACY_XRAY="$WORK/legacy/bin/xray-linux-amd64"
test -f "$LEGACY_XRAY" || fail "legacy custom Xray is missing"

ACTUAL_XRAY_SHA="$(sha256sum "$LEGACY_XRAY" | awk '{print $1}')"
test "$ACTUAL_XRAY_SHA" = "$CUSTOM_XRAY_SHA256" ||
    fail "legacy custom Xray checksum mismatch"

install -m 0755 "$LEGACY_XRAY" "$BIN_DIR/xray-linux-amd64"
file "$BIN_DIR/xray-linux-amd64" | grep -q 'statically linked' ||
    fail "custom Xray is not statically linked"

fetch_checked() {
    local url="$1" dest="$2" expected="$3"
    curl -fL --retry 5 --retry-all-errors --retry-delay 2 -o "$dest" "$url"
    local actual
    actual="$(sha256sum "$dest" | awk '{print $1}')"
    test "$actual" = "$expected" ||
        fail "checksum mismatch for $dest: got $actual expected $expected"
}

fetch_checked "$MTG_URL" "$WORK/$MTG_ARCHIVE" "$MTG_SHA256"
tar -xzf "$WORK/$MTG_ARCHIVE" -C "$WORK"
install -m 0755     "$WORK/mtg-multi-1.15.0-linux-amd64/mtg-multi"     "$BIN_DIR/mtg-linux-amd64"

fetch_checked     "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/$GEO_MAIN_TAG/geoip.dat"     "$BIN_DIR/geoip.dat"     "$GEO_MAIN_GEOIP_SHA256"
fetch_checked     "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/$GEO_MAIN_TAG/geosite.dat"     "$BIN_DIR/geosite.dat"     "$GEO_MAIN_GEOSITE_SHA256"

fetch_checked     "https://github.com/Chocolate4U/Iran-v2ray-rules/releases/download/$GEO_IR_TAG/geoip.dat"     "$BIN_DIR/geoip_IR.dat"     "$GEO_IR_GEOIP_SHA256"
fetch_checked     "https://github.com/Chocolate4U/Iran-v2ray-rules/releases/download/$GEO_IR_TAG/geosite.dat"     "$BIN_DIR/geosite_IR.dat"     "$GEO_IR_GEOSITE_SHA256"

fetch_checked     "https://github.com/runetfreedom/russia-v2ray-rules-dat/releases/download/$GEO_RU_TAG/geoip.dat"     "$BIN_DIR/geoip_RU.dat"     "$GEO_RU_GEOIP_SHA256"
fetch_checked     "https://github.com/runetfreedom/russia-v2ray-rules-dat/releases/download/$GEO_RU_TAG/geosite.dat"     "$BIN_DIR/geosite_RU.dat"     "$GEO_RU_GEOSITE_SHA256"

cat > "$OUTPUT_ROOT/RUNTIME_SOURCES" <<SOURCES
ARCH=linux-amd64
CUSTOM_XRAY_SOURCE=hadish0123/PRIMEVPN draft legacy-v1.0.0 recovered from PrimeLinkPanel/PRIMEVPN v1.0.0
CUSTOM_XRAY_SHA256=$CUSTOM_XRAY_SHA256
MTG_SOURCE=MHSanaei/mtg-multi $MTG_TAG $MTG_ARCHIVE
MTG_ARCHIVE_SHA256=$MTG_SHA256
GEO_MAIN_SOURCE=Loyalsoldier/v2ray-rules-dat $GEO_MAIN_TAG
GEO_MAIN_GEOIP_SHA256=$GEO_MAIN_GEOIP_SHA256
GEO_MAIN_GEOSITE_SHA256=$GEO_MAIN_GEOSITE_SHA256
GEO_IR_SOURCE=Chocolate4U/Iran-v2ray-rules $GEO_IR_TAG
GEO_IR_GEOIP_SHA256=$GEO_IR_GEOIP_SHA256
GEO_IR_GEOSITE_SHA256=$GEO_IR_GEOSITE_SHA256
GEO_RU_SOURCE=runetfreedom/russia-v2ray-rules-dat $GEO_RU_TAG
GEO_RU_GEOIP_SHA256=$GEO_RU_GEOIP_SHA256
GEO_RU_GEOSITE_SHA256=$GEO_RU_GEOSITE_SHA256
SOURCES

(
    cd "$OUTPUT_ROOT"
    find bin -type f -print0 | sort -z | xargs -0 sha256sum > RUNTIME_SHA256SUMS
)

printf 'RUNTIME_PREPARE=pass\n'
printf 'OUTPUT_ROOT=%s\n' "$OUTPUT_ROOT"
printf 'CUSTOM_XRAY_SHA256=%s\n' "$CUSTOM_XRAY_SHA256"
cat "$OUTPUT_ROOT/RUNTIME_SHA256SUMS"
