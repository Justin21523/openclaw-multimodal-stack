#!/usr/bin/env bash
# 01_backup_openclaw_and_llama_configs.sh
# Back up all OpenClaw and llama.cpp config files before making changes.
set -euo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="${HOME}/.openclaw/backups/multimodal-stack-${TS}"
mkdir -p "${BACKUP_DIR}"

echo "Creating backup in: ${BACKUP_DIR}"

cp "${HOME}/.openclaw/openclaw.json" "${BACKUP_DIR}/openclaw.json"
cp "${HOME}/.openclaw/llamacpp-active.env" "${BACKUP_DIR}/llamacpp-active.env" 2>/dev/null || true
cp /mnt/c/ai_projects/gpu-migration-r9700/configs/llamacpp-model-candidates.json \
   "${BACKUP_DIR}/llamacpp-model-candidates.json" 2>/dev/null || true
cp "${HOME}/.config/systemd/user/llama-server.service" "${BACKUP_DIR}/" 2>/dev/null || true
cp "${HOME}/.config/systemd/user/openclaw-gateway.service" "${BACKUP_DIR}/" 2>/dev/null || true
cp "${HOME}/.config/systemd/user/openclaw-model-control-ui.service" "${BACKUP_DIR}/" 2>/dev/null || true
cp "${HOME}/.openclaw/workspace/model-control-ui/server.js" "${BACKUP_DIR}/server.js" 2>/dev/null || true

echo "Backed up:"
ls -la "${BACKUP_DIR}/"
echo ""
echo "Restore command: cp ${BACKUP_DIR}/openclaw.json ~/.openclaw/openclaw.json"
echo "Restore command: cp ${BACKUP_DIR}/llamacpp-model-candidates.json /mnt/c/ai_projects/gpu-migration-r9700/configs/"
