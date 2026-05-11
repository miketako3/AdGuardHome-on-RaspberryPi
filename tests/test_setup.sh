#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="${ROOT_DIR}/tests/.tmp"
BOOT_DIR="${TMP_DIR}/system-boot"
RENDERED_FILE="${ROOT_DIR}/build/user-data"
TEST_AUTH_KEY="tskey-auth-test-value"

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

echo "[1/4] Validate required env check"
if (cd "${ROOT_DIR}" && make -s render TAILSCALE_AUTH_KEY= BOOT_DIR="${BOOT_DIR}" >/dev/null 2>&1); then
  fail "render should fail when TAILSCALE_AUTH_KEY is missing"
fi

echo "[2/4] Validate template rendering"
(cd "${ROOT_DIR}" && make -s clean >/dev/null)
(cd "${ROOT_DIR}" && make -s render TAILSCALE_AUTH_KEY="${TEST_AUTH_KEY}" BOOT_DIR="${BOOT_DIR}" >/dev/null)

[[ -f "${RENDERED_FILE}" ]] || fail "rendered user-data file was not created"
if grep -q '{{TAILSCALE_AUTH_KEY}}' "${RENDERED_FILE}"; then
  fail "placeholder was not replaced in rendered file"
fi

required_tokens=(
  "package_update: true"
  "docker-compose -f /opt/adguardhome/docker-compose.yml up -d"
  "tailscale up --authkey ${TEST_AUTH_KEY}"
  "network_mode: host"
  "/opt/adguardhome/work:/opt/adguardhome/work"
  "/opt/adguardhome/conf:/opt/adguardhome/conf"
)
for token in "${required_tokens[@]}"; do
  if ! grep -Fq "${token}" "${RENDERED_FILE}"; then
    fail "required token missing: ${token}"
  fi
done

echo "[3/4] Validate no duplicate base OS settings in cloud-init"
for forbidden in '^hostname:' '^users:' 'ssh_authorized_keys' 'ssh_pwauth'; do
  if grep -Eq "${forbidden}" "${RENDERED_FILE}"; then
    fail "forbidden config found: ${forbidden}"
  fi
done

echo "[4/4] Validate install copy to mock boot partition"
mkdir -p "${BOOT_DIR}"
(cd "${ROOT_DIR}" && make -s install TAILSCALE_AUTH_KEY="${TEST_AUTH_KEY}" BOOT_DIR="${BOOT_DIR}" >/dev/null)
[[ -f "${BOOT_DIR}/user-data" ]] || fail "user-data was not copied to BOOT_DIR"
cmp -s "${RENDERED_FILE}" "${BOOT_DIR}/user-data" || fail "copied user-data does not match rendered file"

echo "All tests passed."
