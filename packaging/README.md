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
