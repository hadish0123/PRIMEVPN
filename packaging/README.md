# Packaging

Release and runtime support assets are grouped here so the repository root
remains focused on stable public entrypoints and application source.

## Layout

- `docker/` — container initialization and entrypoint scripts.
- `scripts/` — helper commands included in release archives.
- `migrations/` — standalone migration utilities.
- `windows/` — Windows packaging policy and third-party dependency notes.

The following files intentionally remain in the repository root to preserve
existing installation commands, raw GitHub URLs, update behavior, and older
installed versions:

- `install.sh`
- `update.sh`
- `primevpn.sh`
- `primevpn.rc`
- `primevpn.service.arch`
- `primevpn.service.debian`
- `primevpn.service.rhel`

The lowercase files above are the canonical release/runtime contract. Uppercase
`PRIMEVPN.*` files remain temporarily as legacy compatibility entrypoints for
older installs and raw GitHub URLs; new installers and release archives do not
use them.


## Stable release flow

The stable public artifact is currently **Linux amd64 only**. Release packaging
depends on the audited custom Xray binary and the runtime assets listed by
`packaging/release/build-linux-amd64.sh`; those inputs are intentionally not
stored in this public repository.

On the trusted release machine:

1. Set `PRIMEVPN_CUSTOM_XRAY`, `PRIMEVPN_CUSTOM_XRAY_SHA256`, and
   `PRIMEVPN_EXPECTED_PANEL_SHA256`.
2. Ensure `PRIMEVPN_RUNTIME_BIN_DIR` contains the required mtg and geodata
   files.
3. Run `packaging/release/publish-linux-amd64.sh`.
4. By default it creates a **draft** GitHub release. Review it, then publish it.
   Set `PRIMEVPN_RELEASE_PUBLISH=1` only when immediate publication is wanted.

Every published release is independently checked by the `Release PRIMEVPN`
workflow and then installed from scratch by `Release Install Smoke Tests`.


### Recovered v1.0.0 custom core

The original PrimeLinkPanel `v1.0.0` release was mirrored into the current
repository as the draft archival release `legacy-v1.0.0`. Its original archive
SHA256 is:

`e3d77d7b2e586b1ce6d2fc94078b31e5610ae88904c18932206986acf0c2ee01`

The recovered custom Xray SHA256 is:

`8255dd939c34cf966cc91517b6324dd3c8d0bcf49ffac8beca049a38c46845ed`

`prepare-runtime-amd64.sh` combines that pinned custom core with pinned public
MTG/geodata inputs and writes `RUNTIME_SOURCES` plus `RUNTIME_SHA256SUMS`.
