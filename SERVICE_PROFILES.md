# Service Profiles

## llama-server.service

**Unit file**: `~/.config/systemd/user/llama-server.service`
**Start script**: `~/.openclaw/workspace/scripts/openclaw-llamacpp-server-start.sh`
**Active env**: `~/.openclaw/llamacpp-active.env`

The start script reads `llamacpp-active.env` at each launch. Changing the active model is done via:
```bash
bash scripts/12_llamacpp_model_control.sh set <alias>
systemctl --user restart llama-server.service
```

### Profile: gemma31 (Gemma 4 31B VLM)

```
Port: 8080
Model: /mnt/c/ai_models/language/vlm/gemma-4-31B-it-GGUF/gemma-4-31B-it-Q4_K_M.gguf
mmproj: /mnt/c/ai_models/language/vlm/gemma-4-31B-it-GGUF/mmproj-F16.gguf
ctx: 131072
images: true
mmproj offload: CPU (--no-mmproj-offload)
image-max-tokens: 1120
ubatch-size: 1152
```

### Profile: qwen27 (Qwen3.6 27B Text)

```
Port: 8080
Model: /mnt/c/ai_models/language/llm/Qwen3.6-27B-GGUF/Qwen3.6-27B-Q4_K_M.gguf
mmproj: none
ctx: 131072
images: false
```

### Profile: qwen35 (Qwen3.6 35B-A3B MoE Text)

```
Port: 8080
Model: /mnt/c/ai_models/language/llm/Qwen3.6-35B-A3B-GGUF/Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf
mmproj: none
ctx: 262144
images: false
```

### Profile: qwenvlm32 (Qwen2.5-VL 32B — pending download)

```
Port: 8080
Model: /mnt/c/ai_models/language/vlm/qwen/Qwen2.5-VL-32B/Qwen2.5-VL-32B-Instruct-Q4_K_M.gguf
mmproj: /mnt/c/ai_models/language/vlm/qwen/Qwen2.5-VL-32B/mmproj-Qwen2.5-VL-32B-Instruct-f16.gguf
ctx: 32768
images: true
mmproj offload: CPU (--no-mmproj-offload)
image-max-tokens: 1024
```

---

## openclaw-gateway.service

**Unit file**: `~/.config/systemd/user/openclaw-gateway.service`
**Port**: 18789
**Binary**: `/home/justin/.nvm/versions/node/v22.18.0/bin/node ...openclaw/dist/index.js gateway`

No configuration changes needed for image pipeline fix. The gateway service does not need to know about the `/img` skill explicitly — the skill is registered in `openclaw.json`.

Restart command: `systemctl --user restart openclaw-gateway.service`

---

## openclaw-model-control-ui.service

**Unit file**: `~/.config/systemd/user/openclaw-model-control-ui.service`
**Port**: 18888
**Binary**: `~/.openclaw/runtime/node/bin/node ~/.openclaw/workspace/model-control-ui/server.js`
**Working dir**: `~/.openclaw/workspace/model-control-ui/`

Endpoints:
- `GET /api/status` — current model + service state
- `POST /api/set` — switch active model alias
- `POST /api/start` / `POST /api/stop` / `POST /api/restart` — service control
- `POST /api/image-test` — direct image inference (bypasses chat history)

The `image-analyze-skill.sh` will call `/api/image-test`. This service must be running for the `/img` skill to work.

Restart command: `systemctl --user restart openclaw-model-control-ui.service`

---

## Watchdog Services

**openclaw-stall-watchdog.timer** — kills and restarts llama-server if it stalls.
Started automatically with `restart <alias>`. Stop explicitly if testing long-running inference.

```bash
systemctl --user stop openclaw-stall-watchdog.timer  # disable during testing
systemctl --user start openclaw-stall-watchdog.timer  # re-enable after
```
