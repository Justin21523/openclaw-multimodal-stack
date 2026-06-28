#!/usr/bin/env bash
# 07_research_qwen_vlm_candidates.sh
# Check local disk for existing Qwen VLM files and report candidates.
# Read-only. Does not download anything.
set -euo pipefail

REPORT_DIR="$(dirname "$(dirname "$(realpath "$0")")")/reports"
mkdir -p "${REPORT_DIR}"
REPORT="${REPORT_DIR}/qwen_vlm_candidates_$(date +%Y%m%d_%H%M%S).txt"

log() { echo "$@" | tee -a "${REPORT}"; }

log "=== Qwen VLM Candidates Research ==="
log "Date: $(date)"
log ""

log "=== Existing GGUF models on disk ==="
find /mnt/c/ai_models/language -name "*.gguf" 2>/dev/null | sort | while read -r f; do
  size="$(du -sh "${f}" 2>/dev/null | cut -f1)"
  log "  ${size}  ${f}"
done

log ""
log "=== VLM directory ==="
ls -la /mnt/c/ai_models/language/vlm/ 2>/dev/null | tee -a "${REPORT}"

log ""
log "=== Current model catalog ==="
cat /mnt/c/ai_projects/gpu-migration-r9700/configs/llamacpp-model-candidates.json | tee -a "${REPORT}"

log ""
log "=== Qwen3.6 supportsImages status ==="
python3 -c "
import json
with open('/mnt/c/ai_projects/gpu-migration-r9700/configs/llamacpp-model-candidates.json') as f:
    cat = json.load(f)
for alias, m in cat['models'].items():
    images = m.get('supportsImages', False)
    mmproj = m.get('mmproj', 'none')
    print(f'{alias}: supportsImages={images}, mmproj={mmproj}')
" 2>/dev/null | tee -a "${REPORT}"

log ""
log "=== Conclusion ==="
log "Recommended Qwen VLM for R9700 32GB:"
log "  Option A: Qwen3.6 VL (if mmproj available on HuggingFace)"
log "  Option B: lmstudio-community/Qwen2.5-VL-32B-Instruct-GGUF Q4_K_M (~20 GB)"
log ""
log "See QWEN_VLM_RESEARCH_REPORT.md for full analysis."
log "Report saved to: ${REPORT}"
