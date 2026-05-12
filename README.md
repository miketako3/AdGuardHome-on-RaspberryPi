# AdGuard Home + Tailscale Zero-Touch Provisioning (Raspberry Pi)

[![CI](https://github.com/miketako3/AdGuardHome/actions/workflows/ci.yml/badge.svg)](https://github.com/miketako3/AdGuardHome/actions/workflows/ci.yml)

English | [日本語](README.ja.md)

This repository provides a minimal, declarative setup for Ubuntu Server 24.04 LTS on Raspberry Pi.
It assumes Raspberry Pi Imager already configured hostname, admin user, and SSH key.
`cloud-init` is used only for application provisioning:

- package update/upgrade
- Docker + Docker Compose install
- Tailscale install and non-interactive login
- AdGuard Home deployment with Docker Compose

## Requirements

1. Raspberry Pi with Ubuntu Server 24.04 LTS (64-bit) flashed by Raspberry Pi Imager.
2. Imager settings already applied: hostname, admin user, SSH public key, and password auth disabled.
3. Reusable Tailscale auth key (`tskey-auth-...`).
4. SD card boot partition mounted on your machine, containing Raspberry Pi Imager generated `user-data`.

## Quick Start

1. Create local config:

```bash
cp .env.example .env
```

2. Edit `.env`:

```dotenv
TAILSCALE_AUTH_KEY=tskey-auth-xxxxxxxxxxxx
ADGUARD_ADMIN_USER=admin
ADGUARD_ADMIN_PASSWORD=change-me
ADGUARD_DNS_BIND_HOST=192.168.1.2
BOOT_DIR=/Volumes/system-boot
```

3. Reinsert the SD card after Raspberry Pi Imager finishes writing.
Some environments do not remount the boot partition automatically, so verify the actual mount path under `/Volumes` and update `BOOT_DIR` if needed.

4. Render `user-data`:

```bash
make render
```

5. Run local validation tests:

```bash
make test
```

6. Merge rendered config into the existing Imager `user-data` on the SD boot partition:

```bash
make install
```

7. Insert SD card into Raspberry Pi, connect power + LAN, and boot.

## Verification After Boot

1. Check Tailscale admin console and confirm the node is online.
2. Open `http://<raspberry-pi-ip>/` and confirm AdGuard Home admin UI is reachable.

## Make Targets

- `make render`: render `templates/user-data.tmpl` into `build/user-data`
- `make install`: keep `${BOOT_DIR}/user-data` from Imager and write merged multipart config to `${BOOT_DIR}/user-data`
- `make test`: run local validation tests (including mock boot partition copy)
- `make clean`: remove generated files

## Repository Layout

- `templates/user-data.tmpl`: cloud-init template
- `scripts/merge_user_data.sh`: builds merged multipart `user-data` while preserving Imager settings
- `Makefile`: render/install/test entry points
- `tests/test_setup.sh`: local test suite
- `.env.example`: env var template without secrets
- `.github/workflows/ci.yml`: GitHub Actions CI workflow

## Security Notes

- Secrets are read from `.env` only.
- `.env` is gitignored and must never be committed.
- Rendered files (`build/`) are gitignored.
- `make install` saves a one-time backup of the original Imager config at `${BOOT_DIR}/user-data.imager.orig`.

## CI

GitHub Actions runs `make test` on:

- `push` to `main`
- all `pull_request` events

## Troubleshooting

- `ERROR: TAILSCALE_AUTH_KEY is required`: set `TAILSCALE_AUTH_KEY` in `.env` or shell environment.
- `ERROR: ADGUARD_ADMIN_USER is required`: set `ADGUARD_ADMIN_USER` in `.env` or shell environment.
- `ERROR: ADGUARD_ADMIN_PASSWORD is required`: set `ADGUARD_ADMIN_PASSWORD` in `.env` or shell environment.
- `ERROR: ADGUARD_DNS_BIND_HOST is required`: set `ADGUARD_DNS_BIND_HOST` in `.env` or shell environment.
- `ERROR: htpasswd is required`: install `apache2-utils` (Linux) or `httpd` (macOS Homebrew).
- `ERROR: BOOT_DIR does not exist`: verify the SD boot partition is mounted and `BOOT_DIR` points to it.
- `ERROR: /.../user-data not found`: run Raspberry Pi Imager first so the boot partition has its initial cloud-init files.
- `BOOT_DIR` error right after imaging: remove and reinsert the SD card, then re-check the mounted path in `/Volumes`.
- SSH settings disappeared after a previous run: re-image the SD card once, then use this new merge-based install flow.
- `tailscaled.service` not found right after first boot:
  this usually happens when cloud-init is still processing long first-boot package upgrades before `scripts-user` finishes.
  This repository avoids that delay by running `apt-get upgrade` as the last `runcmd`, after Tailscale and AdGuard startup.
- AdGuard UI not reachable: confirm Raspberry Pi has network connectivity and Docker started correctly on first boot.
