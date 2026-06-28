#!/usr/bin/env bash
# 12_validate_all_multimodal_profiles.sh
# Quick smoke test for all active multimodal-related services.
# Read-only. Does not modify configs.
set -euo pipefail

PASS=0
FAIL=0
SKIP=0

check() {
  local label="$1"
  local result="$2"
  local expected="$3"
  if echo "${result}" | grep -q "${expected}"; then
    echo "  PASS: ${label}"
    PASS=$((PASS+1))
  else
    echo "  FAIL: ${label} (got: ${result:0:80})"
    FAIL=$((FAIL+1))
  fi
}

echo "=== Multimodal Stack Validation ==="
echo ""

echo "--- Service Status ---"
for svc in llama-server openclaw-gateway openclaw-model-control-ui; do
  state="$(systemctl --user is-active "${svc}.service" 2>/dev/null || echo 'inactive')"
  check "${svc}.service active" "${state}" "active"
done
echo ""

echo "--- llama.cpp API ---"
models="$(curl -fsS --connect-timeout 3 --max-time 5 http://127.0.0.1:8080/v1/models 2>/dev/null || echo 'FAIL')"
check "/v1/models responds" "${models}" "data"

active_alias="$(grep '^LLAMACPP_ACTIVE_ALIAS=' ~/.openclaw/llamacpp-active.env 2>/dev/null | cut -d= -f2)"
check "active model is set" "${active_alias}" "."
echo "  active_alias=${active_alias}"

supports_images="$(grep '^LLAMACPP_ACTIVE_SUPPORTS_IMAGES=' ~/.openclaw/llamacpp-active.env 2>/dev/null | cut -d= -f2 || echo 'false')"
check "SUPPORTS_IMAGES is set" "${supports_images}" "."
echo "  supports_images=${supports_images}"
echo ""

echo "--- Model Control UI ---"
ui_status="$(curl -fsS --connect-timeout 3 --max-time 5 http://127.0.0.1:18888/api/status 2>/dev/null || echo 'FAIL')"
check "/api/status responds" "${ui_status}" "status"
echo ""

echo "--- Media Inbound Directory ---"
media_dir="${HOME}/.openclaw/media/inbound"
if [[ -d "${media_dir}" ]]; then
  count="$(find "${media_dir}" -maxdepth 1 -type f 2>/dev/null | wc -l)"
  check "media/inbound exists" "ok" "ok"
  echo "  files in inbound: ${count}"
else
  echo "  SKIP: media/inbound does not exist"
  SKIP=$((SKIP+1))
fi
echo ""

echo "=== Results: PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP} ==="
if [[ ${FAIL} -gt 0 ]]; then
  exit 1
fi
