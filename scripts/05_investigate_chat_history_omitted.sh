#!/usr/bin/env bash
# 05_investigate_chat_history_omitted.sh
# Search for the source of [chat.history omitted: message too large].
# Read-only. Documents findings.
set -euo pipefail

REPORT_DIR="$(dirname "$(dirname "$(realpath "$0")")")/reports"
mkdir -p "${REPORT_DIR}"
REPORT="${REPORT_DIR}/chat_history_omitted_$(date +%Y%m%d_%H%M%S).txt"

log() { echo "$@" | tee -a "${REPORT}"; }

log "=== Chat History Omitted Investigation ==="
log "Date: $(date)"
log ""

log "=== Searching for source files ==="
grep -r "chat.history omitted\|CHAT_HISTORY_OVERSIZED\|TRANSCRIPT_OVERSIZED\|message too large" \
  "${HOME}/.openclaw/runtime/node/lib/node_modules/openclaw/dist/" \
  --include="*.js" -l 2>/dev/null | tee -a "${REPORT}"

log ""
log "=== Key constants in chat-CGlveWq2.js ==="
grep -n "CHAT_HISTORY_MAX_SINGLE\|CHAT_HISTORY_OVERSIZED\|maxChatHistoryMessages\|MAX_WEBCHAT_IMAGE" \
  "${HOME}/.openclaw/runtime/node/lib/node_modules/openclaw/dist/chat-CGlveWq2.js" 2>/dev/null | tee -a "${REPORT}"

log ""
log "=== Key constants in server-constants ==="
grep -n "maxChatHistoryMessages\|MAX_PAYLOAD\|MAX_BUFFERED" \
  "${HOME}/.openclaw/runtime/node/lib/node_modules/openclaw/dist/server-constants-C6ZA_v97.js" 2>/dev/null | tee -a "${REPORT}"

log ""
log "=== Recent gateway log (omitted messages) ==="
journalctl --user -u openclaw-gateway.service -n 500 --no-pager 2>/dev/null \
  | grep -i "omit\|oversiz\|history\|large\|placeholder" | head -20 | tee -a "${REPORT}"

log ""
log "=== openclaw.json history-related settings ==="
python3 -c "
import json
with open('${HOME}/.openclaw/openclaw.json') as f:
    cfg = json.load(f)
settings = {
  'gateway.webchat.chatHistoryMaxChars': cfg.get('gateway',{}).get('webchat',{}).get('chatHistoryMaxChars'),
  'tools.media.image.maxBytes': cfg.get('tools',{}).get('media',{}).get('image',{}).get('maxBytes'),
  'tools.media.image.timeoutSeconds': cfg.get('tools',{}).get('media',{}).get('image',{}).get('timeoutSeconds'),
  'agents.defaults.model.timeoutMs': cfg.get('agents',{}).get('defaults',{}).get('model',{}).get('timeoutMs'),
}
for k, v in settings.items():
    print(f'{k}: {v}')
" 2>/dev/null | tee -a "${REPORT}"

log ""
log "Hardcoded limits (cannot be changed by config):"
log "  CHAT_HISTORY_MAX_SINGLE_MESSAGE_BYTES = 128 * 1024 = 131072 bytes"
log "  maxChatHistoryMessagesBytes = 6 * 1024 * 1024 = 6291456 bytes"
log "  MAX_WEBCHAT_IMAGE_DATA_BYTES = 1500000 bytes (~1.43 MB)"
log ""
log "Conclusion: Any base64 image (~1-2 MB) will always exceed the 128 KB per-message limit."
log "Fix: Use /img skill that routes through /api/image-test (bypasses history)."
log ""
log "Report saved to: ${REPORT}"
