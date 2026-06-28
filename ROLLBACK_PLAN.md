# Rollback Plan

## General Principles

1. Back up every config before changing it.
2. Only one change at a time before validation.
3. The `restart gemma31` command is the universal restore command for the model.
4. OpenClaw Gateway can be restarted without affecting the LLM service.

---

## Rollback: Image Analysis Skill (/img)

This change is purely additive. To roll back:

```bash
# 1. Restore openclaw.json from backup
cp ~/.openclaw/openclaw.json.bak-img-skill-YYYYMMDDHHMMSS ~/.openclaw/openclaw.json

# 2. Delete the skill script
rm ~/.openclaw/workspace/scripts/image-analyze-skill.sh

# 3. Restart gateway
systemctl --user restart openclaw-gateway.service

# 4. Verify text chat works
# 5. Verify /api/image-test works independently
```

---

## Rollback: Model Catalog Change (adding qwenvlm32)

```bash
# Restore catalog backup
cp /mnt/c/ai_projects/gpu-migration-r9700/configs/llamacpp-model-candidates.json.bak \
   /mnt/c/ai_projects/gpu-migration-r9700/configs/llamacpp-model-candidates.json

# Switch back to gemma31
bash /mnt/c/ai_projects/gpu-migration-r9700/scripts/12_llamacpp_model_control.sh restart gemma31

# Verify
systemctl --user status llama-server.service
curl -s http://127.0.0.1:8080/v1/models | jq '.data[0].id'
# Expected: "gemma-4-31B-it-Q4_K_M.gguf"
```

---

## Rollback: openclaw.json Model Metadata Change

```bash
# Find backup
ls -la ~/.openclaw/openclaw.json.bak*

# Restore most recent
cp ~/.openclaw/openclaw.json.bak-YYYYMMDDHHMMSS ~/.openclaw/openclaw.json

# Restart gateway
systemctl --user restart openclaw-gateway.service
```

---

## Rollback: Gemma VLM Broken After Any Change

```bash
# Step 1: Restore active env to Gemma
cat > ~/.openclaw/llamacpp-active.env << 'EOF'
LLAMACPP_ACTIVE_ALIAS=gemma31
LLAMACPP_ACTIVE_MODEL=/mnt/c/ai_models/language/vlm/gemma-4-31B-it-GGUF/gemma-4-31B-it-Q4_K_M.gguf
LLAMACPP_ACTIVE_MODEL_ID=gemma-4-31B-it-Q4_K_M.gguf
LLAMACPP_ACTIVE_CTX=131072
LLAMACPP_ACTIVE_MAX_TOKENS=8192
LLAMACPP_ACTIVE_SUPPORTS_IMAGES=true
LLAMACPP_ACTIVE_MMPROJ=/mnt/c/ai_models/language/vlm/gemma-4-31B-it-GGUF/mmproj-F16.gguf
LLAMACPP_IMAGE_MAX_TOKENS=1120
EOF
chmod 600 ~/.openclaw/llamacpp-active.env

# Step 2: Reload and restart
systemctl --user daemon-reload
systemctl --user restart llama-server.service

# Step 3: Wait for model load (~20s)
sleep 25

# Step 4: Verify
curl -s http://127.0.0.1:8080/v1/models | jq '.'

# Step 5: Test image
curl -s -X POST http://127.0.0.1:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"gemma-4-31B-it-Q4_K_M.gguf","messages":[{"role":"user","content":[{"type":"text","text":"Say OK"},{"type":"image_url","image_url":{"url":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="}}]}],"max_tokens":10}' \
  | jq '.choices[0].message.content'
```

---

## Emergency: Full Service Restore

If all three services are broken:

```bash
# 1. Kill any stuck processes
pkill -f llama-server 2>/dev/null || true
pkill -f "node.*openclaw" 2>/dev/null || true

# 2. Restore Gemma active env (see above)

# 3. Restart all three services
systemctl --user daemon-reload
systemctl --user restart llama-server.service
sleep 5
systemctl --user restart openclaw-gateway.service
sleep 3
systemctl --user restart openclaw-model-control-ui.service

# 4. Check status
systemctl --user status llama-server.service openclaw-gateway.service openclaw-model-control-ui.service

# 5. Check logs for errors
journalctl --user -u openclaw-gateway.service -n 30 --no-pager
```

---

## Backup Checklist (Before Any Change)

```bash
# Run before making any change:
ts=$(date +%Y%m%d%H%M%S)
cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak-${ts}
cp ~/.openclaw/llamacpp-active.env ~/.openclaw/llamacpp-active.env.bak-${ts}
cp /mnt/c/ai_projects/gpu-migration-r9700/configs/llamacpp-model-candidates.json \
   /mnt/c/ai_projects/gpu-migration-r9700/configs/llamacpp-model-candidates.json.bak-${ts}
echo "Backups created with timestamp ${ts}"
```
