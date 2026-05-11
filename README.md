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
4. SD card boot partition mounted on your machine.

## Quick Start

1. Create local config:

```bash
cp .env.example .env
```

2. Edit `.env`:

```dotenv
TAILSCALE_AUTH_KEY=tskey-auth-xxxxxxxxxxxx
BOOT_DIR=/Volumes/system-boot
```

3. Render `user-data`:

```bash
make render
```

4. Run local validation tests:

```bash
make test
```

5. Copy rendered config to the SD boot partition:

```bash
make install
```

6. Insert SD card into Raspberry Pi, connect power + LAN, and boot.

## Verification After Boot

1. Check Tailscale admin console and confirm the node is online.
2. Open `http://<raspberry-pi-ip>:3000` and confirm AdGuard Home setup UI is reachable.

## Make Targets

- `make render`: render `templates/user-data.tmpl` into `build/user-data`
- `make install`: copy `build/user-data` to `${BOOT_DIR}/user-data`
- `make test`: run local validation tests (including mock boot partition copy)
- `make clean`: remove generated files

## Repository Layout

- `templates/user-data.tmpl`: cloud-init template
- `Makefile`: render/install/test entry points
- `tests/test_setup.sh`: local test suite
- `.env.example`: env var template without secrets
- `.github/workflows/ci.yml`: GitHub Actions CI workflow

## Security Notes

- Secrets are read from `.env` only.
- `.env` is gitignored and must never be committed.
- Rendered files (`build/`) are gitignored.

## CI

GitHub Actions runs `make test` on:

- `push` to `main`
- all `pull_request` events

## Troubleshooting

- `ERROR: TAILSCALE_AUTH_KEY is required`: set `TAILSCALE_AUTH_KEY` in `.env` or shell environment.
- `ERROR: BOOT_DIR does not exist`: verify the SD boot partition is mounted and `BOOT_DIR` points to it.
- AdGuard UI not reachable: confirm Raspberry Pi has network connectivity and Docker started correctly on first boot.
