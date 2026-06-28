# OpenClaw Image Pipeline Fix Plan

## Problem

The `[chat.history omitted: message too large]` error breaks image analysis through the normal webchat UI after the first turn. Root cause: hardcoded 128 KB per-message limit in the compiled OpenClaw bundle causes base64 image data URLs (~1-2 MB) to be replaced with a placeholder string before being sent to llama.cpp.

Full diagnosis: `CHAT_HISTORY_OMITTED_INVESTIGATION.md`

## Recommended Fix: Dedicated `/img` Skill

### Concept

Instead of routing image analysis through the normal chat path (which stores images as base64 in history), create a custom OpenClaw skill that:

1. Accepts the user's image path + analysis prompt
2. Reads the image from `~/.openclaw/media/inbound/` (where OpenClaw saves uploaded images)
3. Calls the Model Control UI `/api/image-test` endpoint directly (already tested and working)
4. Returns the text analysis result — never stores the image in chat history

### Why This is Safe

- No modification to compiled OpenClaw code
- No modification to llama-server.service
- The `/api/image-test` path is already proven to work
- The skill result is plain text — trivially fits in chat history
- Does not break any existing text chat or Gemma VLM configuration

### Implementation

#### Step 1: Create the analysis script

**File**: `~/.openclaw/workspace/scripts/image-analyze-skill.sh`

```bash
#!/usr/bin/env bash
# image-analyze-skill.sh — analyze most recent inbound image via Model Control UI
set -euo pipefail

INBOUND_DIR="${HOME}/.openclaw/media/inbound"
MODEL_UI_URL="http://127.0.0.1:18888/api/image-test"
MAX_IMAGE_BYTES=5000000  # 5 MB — generous limit

PROMPT="${1:-請用繁體中文詳細說明這張圖片的內容。}"

# Find the most recently modified image in the inbound directory
latest_image="$(find "${INBOUND_DIR}" -maxdepth 1 -type f \
    \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \) \
    -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | awk '{print $2}')"

if [[ -z "${latest_image}" ]]; then
    echo "ERROR: No image found in ${INBOUND_DIR}. Please upload an image first."
    exit 1
fi

# Get MIME type
ext="${latest_image##*.}"
case "${ext,,}" in
    jpg|jpeg) mime="image/jpeg" ;;
    png)      mime="image/png" ;;
    gif)      mime="image/gif" ;;
    webp)     mime="image/webp" ;;
    *)        mime="image/jpeg" ;;
esac

# Size check
img_bytes="$(stat -c%s "${latest_image}" 2>/dev/null || echo 0)"
if (( img_bytes > MAX_IMAGE_BYTES )); then
    echo "ERROR: Image too large (${img_bytes} bytes > ${MAX_IMAGE_BYTES} limit). Please use a smaller image."
    exit 1
fi

# Encode to base64 data URL
data_url="data:${mime};base64,$(base64 -w 0 "${latest_image}")"

# Call Model Control UI image test endpoint
result="$(curl -fsS --connect-timeout 5 --max-time 260 \
    -X POST "${MODEL_UI_URL}" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg url "${data_url}" --arg prompt "${PROMPT}" \
         '{dataUrl: $url, prompt: $prompt}')" \
    2>/dev/null)"

if [[ -z "${result}" ]]; then
    echo "ERROR: No response from Model Control UI (is openclaw-model-control-ui.service running?)"
    exit 1
fi

# Extract text from result
text="$(echo "${result}" | jq -r '.result.text // .error // "ERROR: unexpected response"' 2>/dev/null)"
filename="$(basename "${latest_image}")"

echo "**Image Analysis** (${filename})"
echo ""
echo "${text}"
```

#### Step 2: Add the skill to openclaw.json

Add to `skills` section in `~/.openclaw/openclaw.json`:

```json
{
  "id": "img-analyze",
  "trigger": "/img",
  "description": "Analyze the most recent image in the media inbound directory using Gemma VLM",
  "exec": {
    "type": "shell",
    "command": "${HOME}/.openclaw/workspace/scripts/image-analyze-skill.sh",
    "args": ["{{input}}"],
    "timeout": 280
  },
  "replyAs": "assistant"
}
```

#### Step 3: Usage

```
/img 請描述這張圖片中有什麼東西？
/img What is in this image?
/img Analyze the chart and summarize the data.
```

Before typing `/img`, the user uploads an image via the webchat attachment button. OpenClaw saves it to `~/.openclaw/media/inbound/`. The skill reads the most recent file from that directory.

---

## Alternative: Add `/img-path` for Explicit File Path

For more control, a second variant accepts an explicit path:

```
/img-path /path/to/image.jpg Describe this image
```

This allows analysis of any local file, not just the most recent upload.

---

## Image Test Endpoint (Existing, No Change Needed)

The existing Model Control UI endpoint already works correctly:

```
POST http://127.0.0.1:18888/api/image-test
{
  "dataUrl": "data:image/jpeg;base64,...",
  "prompt": "Describe this image"
}
```

No change to this endpoint is needed.

---

## Backup Before Implementation

Before adding the skill:

```bash
cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak-img-skill-$(date +%Y%m%d%H%M%S)
```

---

## Rollback Plan

If the skill causes problems:

1. Remove the skill entry from `openclaw.json` (restore from backup)
2. Delete `~/.openclaw/workspace/scripts/image-analyze-skill.sh`
3. Restart openclaw-gateway.service: `systemctl --user restart openclaw-gateway.service`
4. Verify text chat still works
5. Verify existing `/api/image-test` still works independently

The skill is entirely additive — removing it returns the system to its prior state.

---

## Validation Steps After Implementation

1. Upload a test image via webchat
2. Type `/img Describe this image` in chat
3. Verify response contains image analysis (not placeholder)
4. Send a follow-up text message in the same session
5. Verify history is not corrupted (text replies work)
6. Check that direct image test (`/api/image-test`) still works
7. Check that `openclaw infer image describe` still works

---

## What This Fix Does NOT Solve

- Drag-and-drop image directly into webchat and send without `/img` command: **still hits the 128 KB limit on subsequent turns**. The user must use `/img` command for reliable multi-turn image analysis.
- The `400 Failed to tokenize prompt` embedded agent error: **separate issue, separate fix**.

---

## Implementation Status

- [ ] Awaiting user approval
- [ ] Script created
- [ ] Skill added to openclaw.json
- [ ] Validated
