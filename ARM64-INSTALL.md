# PRIMEVPN on ARM64 (experimental compatibility installer)

The currently published stable release contains **AMD64-only** panel, custom Xray, and MTG executables. This helper does not claim native ARM64 support. It runs the checksum-verified official AMD64 release inside an Ubuntu 24.04 AMD64 container using Docker's QEMU/binfmt emulation.

## Install

On an ARM64 Ubuntu/Debian server with Docker installed and working, use the **standard installer command**. It now detects ARM64 and automatically downloads and runs this compatibility installer. On x86-64, the existing native install path is unchanged.

```bash
bash <(curl -Ls https://raw.githubusercontent.com/hadish0123/PRIMEVPN/main/install.sh)
```

The ARM64 compatibility path installs the latest stable release only; version arguments are not supported yet. To configure the panel port or credentials non-interactively, see the environment variables supported by `install-arm64-docker.sh`.

The installer:
- refuses to overwrite a pre-existing native PRIMEVPN install or an unrelated container; a matching interrupted install is validated and recovered in place, with persistent app/database files preserved;
- enables AMD64 emulation and tests an AMD64 container;
- downloads the latest stable release and verifies both the archive SHA-256 and every checksum inside the archive;
- runs the panel in a dedicated container using host networking;
- keeps application files, SQLite data, logs, and ACME/certificate files under `/opt/primevpn-arm64`;
- saves generated login details in `/opt/primevpn-arm64/INSTALL-INFO.txt` with root-only permissions.

Default panel port is `2053`. If needed, choose a different port by setting `PRIMEVPN_PANEL_PORT` before running the installer. The installer will refuse to use a port already listening on the host.

## Management

```bash
primevpn-arm64 status
primevpn-arm64 restart
primevpn-arm64 stop
primevpn-arm64 start
primevpn-arm64 logs
primevpn-arm64 version
```

Use the web panel for normal configuration. The native systemd updater and interactive upstream management menu are intentionally not exposed by this helper because they assume a native host installation. Updating this deployment needs a container-aware upgrade path.

## Important limitations

- This is an emulation workaround, **not native ARM64 support**. Performance may be significantly lower than native binaries.
- The container uses host networking so panel and proxy listeners can bind directly on the server. Ensure the required firewall ports are open and do not conflict with existing services.
- The first boot installs required Ubuntu packages inside the container and needs network access.
- The initial URL is printed as HTTP. Configure TLS before using real credentials over a public network.
- The installer includes CI regression checks for the normalized web base path and safe recovery. A successful CI run validates shell syntax and recovery invariants, but does not replace a live installation test on your specific VPS.
