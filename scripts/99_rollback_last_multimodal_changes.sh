#!/usr/bin/env bash
# 99_rollback_last_multimodal_changes.sh
# Emergency rollback: restore Gemma VLM and restart all services.
set -euo pipefail

echo "=== Emergency Rollback: Restore Gemma VLM ==="

# 1. Restore active env to Gemma
cat > "${HOME}/.openclaw/llamacpp-active.env" << 'ENVEOF'
LLAMACPP_ACTIVE_ALIAS=gemma31
LLAMACPP_ACTIVE_MODEL=/mnt/c/ai_models/language/vlm/gemma-4-31B-it-GGUF/gemma-4-31B-it-Q4_K_M.gguf
LLAMACPP_ACTIVE_MODEL_ID=gemma-4-31B-it-Q4_K_M.gguf
LLAMACPP_ACTIVE_CTX=131072
LLAMACPP_ACTIVE_MAX_TOKENS=8192
LLAMACPP_ACTIVE_SUPPORTS_IMAGES=true
LLAMACPP_ACTIVE_MMPROJ=/mnt/c/ai_models/language/vlm/gemma-4-31B-it-GGUF/mmproj-F16.gguf
LLAMACPP_IMAGE_MAX_TOKENS=1120
ENVEOF
chmod 600 "${HOME}/.openclaw/llamacpp-active.env"
echo "Active env restored to gemma31"

# 2. Kill any stuck process
pkill -f '[l]lama-server' 2>/dev/null || true
sleep 2

# 3. Restart services
systemctl --user daemon-reload
systemctl --user restart llama-server.service
echo "Waiting 25s for model load..."
sleep 25
systemctl --user restart openclaw-gateway.service
sleep 3
systemctl --user restart openclaw-model-control-ui.service
sleep 2

# 4. Verify
echo ""
echo "=== Service Status ==="
for svc in llama-server openclaw-gateway openclaw-model-control-ui; do
  state="$(systemctl --user is-active "${svc}.service" 2>/dev/null || echo 'unknown')"
  echo "  ${svc}: ${state}"
done

echo ""
echo "=== llama.cpp API ==="
curl -fsS --connect-timeout 3 --max-time 5 http://127.0.0.1:8080/v1/models 2>/dev/null \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print('model:', d['data'][0]['id'])" \
  || echo "API not responding yet (try again in 10s)"

echo ""
echo "Rollback complete. System restored to Gemma VLM."
