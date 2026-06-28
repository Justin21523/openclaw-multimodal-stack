#!/usr/bin/env bash
# 00_readonly_audit_current_multimodal_stack.sh
# Read-only audit of the current multimodal stack.
# Safe to run at any time. Does not modify any files.
set -euo pipefail

REPORT_DIR="$(dirname "$(dirname "$(realpath "$0")")")/reports"
mkdir -p "${REPORT_DIR}"
REPORT="${REPORT_DIR}/audit_$(date +%Y%m%d_%H%M%S).txt"

log() { echo "$@" | tee -a "${REPORT}"; }

log "=== OpenClaw Multimodal Stack Audit ==="
log "Date: $(date)"
log ""

log "=== Service Status ==="
for svc in llama-server openclaw-gateway openclaw-model-control-ui; do
  state="$(systemctl --user is-active "${svc}.service" 2>/dev/null || echo 'not-found')"
  log "${svc}: ${state}"
done

log ""
log "=== Active Model ==="
if [[ -f "${HOME}/.openclaw/llamacpp-active.env" ]]; then
  cat "${HOME}/.openclaw/llamacpp-active.env"
else
  log "llamacpp-active.env not found"
fi | tee -a "${REPORT}"

log ""
log "=== llama.cpp API ==="
curl -fsS --connect-timeout 2 --max-time 5 http://127.0.0.1:8080/v1/models 2>/dev/null \
  | python3 -m json.tool 2>/dev/null || log "API not responding"

log ""
log "=== Model Files on Disk ==="
find /mnt/c/ai_models/language/vlm -name "*.gguf" 2>/dev/null | while read -r f; do
  size="$(du -sh "${f}" 2>/dev/null | cut -f1)"
  log "  ${size}  ${f}"
done
find /mnt/c/ai_models/language/llm -name "*.gguf" 2>/dev/null | while read -r f; do
  size="$(du -sh "${f}" 2>/dev/null | cut -f1)"
  log "  ${size}  ${f}"
done

log ""
log "=== openclaw.json (models section) ==="
python3 -c "
import json
with open('${HOME}/.openclaw/openclaw.json') as f:
    cfg = json.load(f)
print(json.dumps(cfg.get('models', {}), indent=2))
" 2>/dev/null | tee -a "${REPORT}"

log ""
log "=== Media Inbound ==="
ls -la "${HOME}/.openclaw/media/inbound/" 2>/dev/null | head -20 | tee -a "${REPORT}"

log ""
log "=== llama-server.service (PID / command) ==="
systemctl --user show llama-server.service --property=MainPID,ExecStart 2>/dev/null | tee -a "${REPORT}"

log ""
log "Audit saved to: ${REPORT}"
