#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <base-user-data> <overlay-user-data> <output-user-data>" >&2
  exit 1
fi

BASE_USER_DATA="$1"
OVERLAY_USER_DATA="$2"
OUTPUT_USER_DATA="$3"
BOUNDARY="===============AGH_$(date +%s)_${RANDOM}=="

[[ -f "${BASE_USER_DATA}" ]] || { echo "Base user-data not found: ${BASE_USER_DATA}" >&2; exit 1; }
[[ -f "${OVERLAY_USER_DATA}" ]] || { echo "Overlay user-data not found: ${OVERLAY_USER_DATA}" >&2; exit 1; }

{
  echo "Content-Type: multipart/mixed; boundary=\"${BOUNDARY}\""
  echo "MIME-Version: 1.0"
  echo "X-AdGuardHome-Merged: true"
  echo

  echo "--${BOUNDARY}"
  echo "Content-Type: text/cloud-config; charset=\"us-ascii\""
  echo "MIME-Version: 1.0"
  echo "Content-Transfer-Encoding: 7bit"
  echo "Content-Disposition: attachment; filename=\"00-imager-user-data.cfg\""
  echo
  cat "${BASE_USER_DATA}"
  echo

  echo "--${BOUNDARY}"
  echo "Content-Type: text/cloud-config; charset=\"us-ascii\""
  echo "MIME-Version: 1.0"
  echo "Content-Transfer-Encoding: 7bit"
  echo "Content-Disposition: attachment; filename=\"99-adguardhome-overlay.cfg\""
  echo "X-Merge-Type: list(append)+dict(no_replace,recurse_list)+str()"
  echo
  cat "${OVERLAY_USER_DATA}"
  echo

  echo "--${BOUNDARY}--"
} > "${OUTPUT_USER_DATA}"
