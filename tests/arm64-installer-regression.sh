#!/usr/bin/env bash
set -Eeuo pipefail

installer="install-arm64-docker.sh"
[[ -s "$installer" ]] || { echo "Missing $installer" >&2; exit 1; }

assert_contains() {
  local needle="$1"
  grep -Fq -- "$needle" "$installer" || {
    echo "Regression check failed: missing expected installer logic: $needle" >&2
    exit 1
  }
}

assert_contains 'grep -Fqx "webBasePath: /$PRIMEVPN_WEB_BASE_PATH/"'
assert_contains "grep -Fq 'grep -Fqx \"webBasePath: \$PRIMEVPN_WEB_BASE_PATH\"' \"\$BASE_DIR/entrypoint.sh\""
assert_contains 'RECOVERABLE_TREE=0'
assert_contains 'if [[ "$CONTAINER_EXISTS" -eq 1 || "$RECOVERABLE_TREE" -eq 1 ]]; then'
assert_contains '(cd "$BASE_DIR/dist/primevpn" && sha256sum -c SHA256SUMS)'
assert_contains 'docker rm -f "$CONTAINER_NAME"'
assert_contains '"$BASE_DIR/state:/etc/primevpn"'
assert_contains '"$BASE_DIR/bootstrap.env:/run/primevpn-bootstrap.env:ro"'

# Verify the exact sed repair used on a server's previously generated entrypoint.
tmp_entrypoint="$(mktemp)"
trap 'rm -f "$tmp_entrypoint"' EXIT
printf '%s\n' 'grep -Fqx "webBasePath: $PRIMEVPN_WEB_BASE_PATH"' > "$tmp_entrypoint"
sed -i 's|grep -Fqx "webBasePath: \$PRIMEVPN_WEB_BASE_PATH"|grep -Fqx "webBasePath: /\$PRIMEVPN_WEB_BASE_PATH/"|' "$tmp_entrypoint"
grep -Fqx 'grep -Fqx "webBasePath: /$PRIMEVPN_WEB_BASE_PATH/"' "$tmp_entrypoint"

# A crash-retry must validate every old container mount before it removes that container.
rm_line="$(grep -nF 'docker rm -f "$CONTAINER_NAME"' "$installer" | head -n 1 | cut -d: -f1)"
for needle in \
  "does not use this install's state directory" \
  "does not use this install's release files" \
  "does not use this install's app directory" \
  "does not use this install's log directory" \
  "does not use this install's ACME directory" \
  "does not use this install's certificate directory" \
  "does not use this install's bootstrap configuration"; do
  line="$(grep -nF "$needle" "$installer" | head -n 1 | cut -d: -f1)"
  [[ -n "$line" && "$line" -lt "$rm_line" ]] || {
    echo "Recovery must validate mount before removing container: $needle" >&2
    exit 1
  }
done

# The persistent app/database must never be wiped by the recovery handler.
if grep -E 'rm[[:space:]]+-rf[[:space:]].*(BASE_DIR/(state|app|dist|logs|acme|cert))' "$installer"; then
  echo "Recovery must not recursively delete persistent install data." >&2
  exit 1
fi

echo "ARM64 installer recovery regression checks passed."
