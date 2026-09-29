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

REPOSITORY="${PRIMEVPN_GITHUB_REPOSITORY:-hadish0123/PRIMEVPN}"
VERSION="$(tr -d '[:space:]' < "$REPO_ROOT/internal/config/version")"
TAG="${1:-v$VERSION}"
NOTES_FILE="${2:-}"
OUTPUT_DIR="${PRIMEVPN_RELEASE_OUTPUT_DIR:-$REPO_ROOT/release-out}"
ARCHIVE="$OUTPUT_DIR/primevpn-linux-amd64.tar.gz"
SHA_FILE="$ARCHIVE.sha256"

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

need() {
    command -v "$1" >/dev/null 2>&1 ||
        fail "missing required tool: $1"
}

for tool in git gh sha256sum; do
    need "$tool"
done

test "$TAG" = "v$VERSION" ||
    fail "release tag must match internal version exactly: expected v$VERSION, got $TAG"

test -z "$(git -C "$REPO_ROOT" status --porcelain)" ||
    fail "release source must be clean"

HEAD_SHA="$(git -C "$REPO_ROOT" rev-parse HEAD)"

gh auth status >/dev/null 2>&1 ||
    fail "GitHub CLI is not authenticated"

if gh release view "$TAG" --repo "$REPOSITORY" >/dev/null 2>&1; then
    fail "GitHub release already exists: $TAG"
fi

CURRENT_REPOSITORY="$(git -C "$REPO_ROOT" remote get-url origin >/dev/null 2>&1 && cd "$REPO_ROOT" && gh repo view --json nameWithOwner --jq .nameWithOwner)"
test "$CURRENT_REPOSITORY" = "$REPOSITORY" ||
    fail "git origin resolves to $CURRENT_REPOSITORY, expected $REPOSITORY"

git -C "$REPO_ROOT" fetch --tags --quiet

printf 'Building PRIMEVPN %s from %s\n' "$TAG" "$HEAD_SHA"
"$SCRIPT_DIR/build-linux-amd64.sh"

"$SCRIPT_DIR/verify-release-archive.sh" \
    "$ARCHIVE" \
    "$SHA_FILE" \
    "$VERSION" \
    "$HEAD_SHA"

if git -C "$REPO_ROOT" rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
    TAG_SHA="$(git -C "$REPO_ROOT" rev-list -n1 "$TAG")"
    test "$TAG_SHA" = "$HEAD_SHA" ||
        fail "existing tag $TAG points to $TAG_SHA, not current HEAD $HEAD_SHA"
else
    git -C "$REPO_ROOT" tag -a "$TAG" "$HEAD_SHA" -m "PRIMEVPN $TAG"
    git -C "$REPO_ROOT" push origin "refs/tags/$TAG"
fi

args=(
    release create "$TAG"
    "$ARCHIVE"
    "$SHA_FILE"
    --repo "$REPOSITORY"
    --verify-tag
    --title "PRIMEVPN $TAG"
)

if [[ -n "$NOTES_FILE" ]]; then
    test -f "$NOTES_FILE" || fail "release notes file not found: $NOTES_FILE"
    args+=(--notes-file "$NOTES_FILE")
else
    args+=(--generate-notes)
fi

if [[ "${PRIMEVPN_RELEASE_PUBLISH:-0}" != "1" ]]; then
    args+=(--draft)
    printf 'Creating a DRAFT release. Set PRIMEVPN_RELEASE_PUBLISH=1 to publish immediately.\n'
else
    printf 'Creating and publishing the release immediately.\n'
fi

gh "${args[@]}"

printf 'RELEASE_CREATED=%s\n' "$TAG"
printf 'REPOSITORY=%s\n' "$REPOSITORY"
printf 'SOURCE_HEAD=%s\n' "$HEAD_SHA"
printf 'ARCHIVE=%s\n' "$ARCHIVE"
printf 'SHA256=%s\n' "$(sha256sum "$ARCHIVE" | awk '{print $1}')"
