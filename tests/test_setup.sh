#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="${ROOT_DIR}/tests/.tmp"
BOOT_DIR="${TMP_DIR}/system-boot"
RENDERED_FILE="${ROOT_DIR}/build/user-data"
MERGED_FILE="${ROOT_DIR}/build/user-data.merged"
BOOT_USER_DATA="${BOOT_DIR}/user-data"
BOOT_USER_DATA_ORIG="${BOOT_DIR}/user-data.imager.orig"
TEST_AUTH_KEY="tskey-auth-test-value"
TEST_AUTH_KEY_2="tskey-auth-test-value-2"
TEST_ADGUARD_USER="miketako3"
TEST_ADGUARD_PASSWORD="test-adguard-password"
TEST_ADGUARD_BIND_HOST="192.168.1.2"

cleanup() {
  rm -rf "${TMP_DIR}"
  (cd "${ROOT_DIR}" && make -s clean >/dev/null 2>&1 || true)
}
trap cleanup EXIT

mkdir -p "${TMP_DIR}" "${BOOT_DIR}"

fail() {
  echo "TEST FAILED: $1" >&2
  exit 1
}

echo "[1/7] Validate required env check for TAILSCALE_AUTH_KEY"
if (cd "${ROOT_DIR}" && make -s render TAILSCALE_AUTH_KEY= ADGUARD_ADMIN_USER="${TEST_ADGUARD_USER}" ADGUARD_ADMIN_PASSWORD="${TEST_ADGUARD_PASSWORD}" ADGUARD_DNS_BIND_HOST="${TEST_ADGUARD_BIND_HOST}" BOOT_DIR="${BOOT_DIR}" >/dev/null 2>&1); then
  fail "render should fail when TAILSCALE_AUTH_KEY is missing"
fi

echo "[2/7] Validate required env check for ADGUARD_ADMIN_USER"
if (cd "${ROOT_DIR}" && make -s render TAILSCALE_AUTH_KEY="${TEST_AUTH_KEY}" ADGUARD_ADMIN_USER= ADGUARD_ADMIN_PASSWORD="${TEST_ADGUARD_PASSWORD}" ADGUARD_DNS_BIND_HOST="${TEST_ADGUARD_BIND_HOST}" BOOT_DIR="${BOOT_DIR}" >/dev/null 2>&1); then
  fail "render should fail when ADGUARD_ADMIN_USER is missing"
fi

echo "[3/7] Validate required env check for ADGUARD_ADMIN_PASSWORD"
if (cd "${ROOT_DIR}" && make -s render TAILSCALE_AUTH_KEY="${TEST_AUTH_KEY}" ADGUARD_ADMIN_USER="${TEST_ADGUARD_USER}" ADGUARD_ADMIN_PASSWORD= ADGUARD_DNS_BIND_HOST="${TEST_ADGUARD_BIND_HOST}" BOOT_DIR="${BOOT_DIR}" >/dev/null 2>&1); then
  fail "render should fail when ADGUARD_ADMIN_PASSWORD is missing"
fi

echo "[4/7] Validate required env check for ADGUARD_DNS_BIND_HOST"
if (cd "${ROOT_DIR}" && make -s render TAILSCALE_AUTH_KEY="${TEST_AUTH_KEY}" ADGUARD_ADMIN_USER="${TEST_ADGUARD_USER}" ADGUARD_ADMIN_PASSWORD="${TEST_ADGUARD_PASSWORD}" ADGUARD_DNS_BIND_HOST= BOOT_DIR="${BOOT_DIR}" >/dev/null 2>&1); then
  fail "render should fail when ADGUARD_DNS_BIND_HOST is missing"
fi

echo "[5/7] Validate template rendering"
(cd "${ROOT_DIR}" && make -s clean >/dev/null)
(cd "${ROOT_DIR}" && make -s render TAILSCALE_AUTH_KEY="${TEST_AUTH_KEY}" ADGUARD_ADMIN_USER="${TEST_ADGUARD_USER}" ADGUARD_ADMIN_PASSWORD="${TEST_ADGUARD_PASSWORD}" ADGUARD_DNS_BIND_HOST="${TEST_ADGUARD_BIND_HOST}" BOOT_DIR="${BOOT_DIR}" >/dev/null)

[[ -f "${RENDERED_FILE}" ]] || fail "rendered user-data file was not created"
if grep -q '{{TAILSCALE_AUTH_KEY}}' "${RENDERED_FILE}"; then
  fail "placeholder was not replaced in rendered file"
fi
if grep -q '{{ADGUARD_ADMIN_USER}}' "${RENDERED_FILE}"; then
  fail "admin user placeholder was not replaced in rendered file"
fi
if grep -q '{{ADGUARD_ADMIN_PASSWORD_HASH}}' "${RENDERED_FILE}"; then
  fail "admin password hash placeholder was not replaced in rendered file"
fi
if grep -q '{{ADGUARD_DNS_BIND_HOST}}' "${RENDERED_FILE}"; then
  fail "bind host placeholder was not replaced in rendered file"
fi
if grep -Fq "${TEST_ADGUARD_PASSWORD}" "${RENDERED_FILE}"; then
  fail "rendered file contains plain AdGuard admin password"
fi

required_tokens=(
  "package_update: true"
  "package_upgrade: true"
  "docker compose -f /opt/adguardhome/docker-compose.yml up -d"
  "tailscale up --authkey ${TEST_AUTH_KEY}"
  "network_mode: host"
  "/opt/adguardhome/work:/opt/adguardhome/work"
  "/opt/adguardhome/conf:/opt/adguardhome/conf"
  "path: /opt/adguardhome/conf/AdGuardHome.yaml"
  "name: ${TEST_ADGUARD_USER}"
  "- ${TEST_ADGUARD_BIND_HOST}"
)
for token in "${required_tokens[@]}"; do
  if ! grep -Fq -- "${token}" "${RENDERED_FILE}"; then
    fail "required token missing: ${token}"
  fi
done

if ! grep -Eq 'password: \$2[abxy]\$10\$' "${RENDERED_FILE}"; then
  fail "AdGuard admin password does not look like a bcrypt hash"
fi

echo "[6/7] Validate no duplicate base OS settings in cloud-init"
for forbidden in '^hostname:' '^users:' 'ssh_authorized_keys' 'ssh_pwauth'; do
  if grep -Eq "${forbidden}" "${RENDERED_FILE}"; then
    fail "forbidden config found: ${forbidden}"
  fi
done

echo "[7/7] Validate install merges with existing Imager user-data"
mkdir -p "${BOOT_DIR}"
cat > "${BOOT_USER_DATA}" <<'EOF'
#cloud-config
hostname: adguard-pi
users:
  - name: kaito
    groups: [sudo]
    ssh_authorized_keys:
      - ssh-ed25519 AAAATESTKEY kaito@local
ssh_pwauth: false
EOF

(cd "${ROOT_DIR}" && make -s install TAILSCALE_AUTH_KEY="${TEST_AUTH_KEY}" ADGUARD_ADMIN_USER="${TEST_ADGUARD_USER}" ADGUARD_ADMIN_PASSWORD="${TEST_ADGUARD_PASSWORD}" ADGUARD_DNS_BIND_HOST="${TEST_ADGUARD_BIND_HOST}" BOOT_DIR="${BOOT_DIR}" >/dev/null)

[[ -f "${BOOT_USER_DATA_ORIG}" ]] || fail "original Imager user-data backup was not created"
[[ -f "${BOOT_USER_DATA}" ]] || fail "merged user-data was not written"
[[ -f "${MERGED_FILE}" ]] || fail "merged build file was not created"

if ! grep -Fq 'Content-Type: multipart/mixed' "${BOOT_USER_DATA}"; then
  fail "merged user-data is not multipart MIME"
fi

if ! grep -Fq 'X-AdGuardHome-Merged: true' "${BOOT_USER_DATA}"; then
  fail "merged user-data marker missing"
fi

if ! grep -Fq 'hostname: adguard-pi' "${BOOT_USER_DATA}"; then
  fail "original Imager cloud-config was not preserved"
fi

if ! grep -Fq 'ssh-ed25519 AAAATESTKEY kaito@local' "${BOOT_USER_DATA}"; then
  fail "original Imager SSH key was not preserved"
fi

if ! grep -Fq "tailscale up --authkey ${TEST_AUTH_KEY}" "${BOOT_USER_DATA}"; then
  fail "overlay cloud-config not merged into user-data"
fi
if ! grep -Fq "name: ${TEST_ADGUARD_USER}" "${BOOT_USER_DATA}"; then
  fail "AdGuard admin user was not rendered into merged user-data"
fi
if ! grep -Eq 'password: \$2[abxy]\$10\$' "${BOOT_USER_DATA}"; then
  fail "AdGuard admin password hash was not rendered into merged user-data"
fi
if ! grep -Fq -- "- ${TEST_ADGUARD_BIND_HOST}" "${BOOT_USER_DATA}"; then
  fail "AdGuard bind host was not rendered into merged user-data"
fi

# Re-run install and ensure it still uses the original Imager config as base.
(cd "${ROOT_DIR}" && make -s install TAILSCALE_AUTH_KEY="${TEST_AUTH_KEY_2}" ADGUARD_ADMIN_USER="${TEST_ADGUARD_USER}" ADGUARD_ADMIN_PASSWORD="${TEST_ADGUARD_PASSWORD}" ADGUARD_DNS_BIND_HOST="${TEST_ADGUARD_BIND_HOST}" BOOT_DIR="${BOOT_DIR}" >/dev/null)
if ! grep -Fq "tailscale up --authkey ${TEST_AUTH_KEY_2}" "${BOOT_USER_DATA}"; then
  fail "second install did not refresh overlay section"
fi

if [[ "$(rg -c '00-imager-user-data.cfg' "${BOOT_USER_DATA}")" -ne 1 ]]; then
  fail "merged user-data appears to be nested repeatedly"
fi

echo "All tests passed."
