# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`step-certctl` is a Bash-based certificate lifecycle manager for [Smallstep CA](https://smallstep.com/certificates/). It is packaged as a Debian `.deb` and designed for homelabs and internal infrastructure (Proxmox, nginx, custom apps, etc.).

## Build Commands

```bash
# Build the .deb package
./build.sh

# Build and install
sudo ./build.sh install

# Clean build artifacts
./build.sh clean

# Verify package contents
./build.sh verify
```

The build script assembles files from `bin/`, `lib/`, `systemd/`, `examples/`, and `debian/` into `pkg/`, then calls `dpkg-deb` to produce `step-certctl_0.1.0_all.deb`.

## Architecture

The project is a pure Bash tool with no test suite. All logic lives in two shell scripts:

- **`bin/step-certctl`** — The main executable. Contains all command implementations (`cmd_issue`, `cmd_renew`, `cmd_validate`, `cmd_install_timer`, `cmd_remove_timer`, `cmd_list`). In development mode it sources `lib/step-certctl-functions.sh` via relative path; when installed it sources `/usr/lib/step-certctl/functions.sh`.
- **`lib/step-certctl-functions.sh`** — Currently a stub/placeholder for shared utilities. Expand here when adding helpers that need to be shared.

**Config-driven model:** Each managed certificate has a `.conf` file at `/etc/step-certctl/<name>.conf` (shell-sourced by the main script). Required variables: `CERT_FILE`, `KEY_FILE`, `CA_URL`, `ROOT_CA`, `COMMON_NAME`. Optional: `SAN`, `EXPIRES_IN`, `RELOAD_CMD`, `OWNER`, `GROUP`, `CERT_MODE`, `KEY_MODE`, `PROVISIONER`, `PROVISIONER_PASSWORD_FILE`, `CERT_TEMPLATE`.

**Systemd integration:** `systemd/step-certctl@.service` and `step-certctl@.timer` are templated units — the instance name (e.g., `pveproxy`) maps to the config file name. The timer fires 5 min after boot, then every 6 hours with a 15-min random jitter.

**Smart renewal:** `cmd_renew` writes to temp files first, compares public keys via `openssl x509 -pubkey` before replacing, and only runs `RELOAD_CMD` if the certificate actually changed.

## Package Structure (installed)

```
/usr/bin/step-certctl                      # Main command
/usr/lib/step-certctl/functions.sh         # Shared functions library
/etc/step-certctl/*.conf                   # Per-certificate configs (user-created)
/etc/systemd/system/step-certctl@.service  # Templated service unit
/etc/systemd/system/step-certctl@.timer    # Templated timer unit
/usr/share/doc/step-certctl/examples/      # Example configs
```

## Dependencies

Runtime (declared in `debian/control`): `step-cli`, `systemd`, `openssl`, `curl`.

## Versioning

Version is hardcoded in two places: `bin/step-certctl` (`VERSION="0.1.0"`) and `build.sh` (`VERSION="0.1.0"`). Update both when bumping the version, along with `debian/control` and `debian/changelog`.
