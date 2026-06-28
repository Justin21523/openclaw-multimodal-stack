# Investigation: `[chat.history omitted: message too large]`

## Summary

The string `[chat.history omitted: message too large]` is generated inside the compiled OpenClaw gateway bundle. It is a **hardcoded placeholder** that replaces any single chat history message exceeding 128 KB before the message array is sent to the LLM backend.

Because a base64-encoded image data URL is typically 1–2 MB in size, **every image-bearing chat message will always exceed the 128 KB limit**. The result: after an image is sent in the first turn, its history entry is replaced by the placeholder in all subsequent turns. llama.cpp receives the placeholder text instead of the image.

---

## Source Location

**File**: `~/.openclaw/runtime/node/lib/node_modules/openclaw/dist/chat-CGlveWq2.js`

### Hardcoded Constants (cannot be changed by config)

```js
// Line 557
const CHAT_HISTORY_MAX_SINGLE_MESSAGE_BYTES = 128 * 1024;   // 128 KB per message
const CHAT_HISTORY_OVERSIZED_PLACEHOLDER = "[chat.history omitted: message too large]";

// From server-constants-C6ZA_v97.js
let maxChatHistoryMessagesBytes = 6 * 1024 * 1024;          // 6 MB total budget
const MAX_WEBCHAT_IMAGE_DATA_BYTES = 1_500_000;              // ~1.43 MB max image
const MAX_WEBCHAT_IMAGE_DATA_URL_CHARS = 2_000_000;          // 2 M chars max data URL
```

### Triggering Logic

```js
// Line ~1442 — chat.history handler
function replaceOversizedChatHistoryMessages(params) {
    const { messages, maxSingleMessageBytes } = params;
    // If any single message JSON > 128 KB → replace with placeholder
    return messages.map(message => {
        if (jsonUtf8Bytes(message) <= maxSingleMessageBytes) return message;
        return buildOversizedHistoryPlaceholder(message);  // ← placeholder here
    });
}
```

### Secondary Placeholder (transcript file)

**File**: `session-utils.fs-D-MAAH1K.js` line 546

```js
const TRANSCRIPT_OVERSIZED_MESSAGE_PLACEHOLDER = "[chat.history omitted: message too large]";
const OVERSIZED_TRANSCRIPT_METADATA_PREFIX_CHARS = 64 * 1024;  // 64 KB
```

This is the placeholder used when writing to the disk transcript. The actual LLM request placeholder comes from `chat-CGlveWq2.js`.

---

## Step-by-Step Failure Sequence

```
Turn 1 — User sends image + prompt
  → Image is encoded as base64 data URL (~1.5 MB string)
  → Stored in chat history message content as: {type: "input_image", image_url: "data:image/..."}
  → LLM receives the actual image → responds correctly ✓

Turn 2 — User sends follow-up (text only)
  → OpenClaw loads chat history for context
  → Calls replaceOversizedChatHistoryMessages()
  → Turn 1 message (1.5 MB) >> 128 KB limit
  → Turn 1 message is replaced: {content: [{type: "text", text: "[chat.history omitted: message too large]"}]}
  → LLM receives: "I sent an image [placeholder]" + new text prompt
  → LLM has no image → cannot refer to it ✗

Turn 1 image-only (first turn) can still work but only if:
  - No existing oversized history from prior turns
  - Model Control UI Image Test endpoint is used (bypasses history entirely)
```

---

## Why Dedicated Endpoints Work

### Model Control UI `/api/image-test` (port 18888)

```js
async function callLlamaImage({ dataUrl, prompt }) {
    // Sends EXACTLY this to llama.cpp:
    const body = {
        model: "<current model>",
        messages: [{
            role: "user",
            content: [
                { type: "text", text: prompt },
                { type: "image_url", image_url: { url: dataUrl } }
            ]
        }],
        max_tokens: 240,
        temperature: 0.1
    };
    // NO chat history. Direct call to http://127.0.0.1:8080/v1/chat/completions
}
```

### `openclaw infer image describe`

Also a direct one-shot inference call. No chat history involved.

---

## Is Image Stored as Base64 in History?

**Yes.** The webchat path embeds the full base64 data URL as an `input_image` content block inside the chat history message. The theoretical maximum (accepted by `resolveEmbeddableImageUrl`) is ~1.43 MB decoded / ~2 M characters as base64. Any typical JPEG or PNG photo will produce a message far exceeding the 128 KB limit.

---

## Can Media Path References Solve This?

llama.cpp with `--media-path ~/.openclaw/media/inbound` supports referencing images by local file path. OpenClaw does save uploaded images to `~/.openclaw/media/inbound/` (line 842: `saveMediaBuffer(Buffer.from(img.data, "base64"), img.mimeType, "inbound")`).

**However**: The webchat chat history path (`resolveEmbeddableImageUrl`) only handles `data:image/...` URLs, not file paths. The file path mechanism is used only for the agent/tool path (`trustedLocalMedia = true`), not for webchat history reconstruction.

**Conclusion**: Media path references are not usable in the chat history path without modifying the compiled OpenClaw bundle — which is unsafe.

---

## Configurable Fields (What Can Be Changed)

| Field | Location | Current Value | Effect on Issue |
|-------|----------|---------------|----------------|
| `gateway.webchat.chatHistoryMaxChars` | openclaw.json | 50,000 | Controls TEXT chars only, does not affect the 128 KB byte limit |
| `tools.media.image.maxBytes` | openclaw.json | 52,428,800 | Controls tool-path image size, not webchat history |
| `agents.defaults.model.timeoutMs` | openclaw.json | 240,000 | Timeout only |
| `CHAT_HISTORY_MAX_SINGLE_MESSAGE_BYTES` | hardcoded in compiled JS | 131,072 | **Cannot be changed** |
| `maxChatHistoryMessagesBytes` | hardcoded in compiled JS | 6,291,456 | **Cannot be changed** |

---

## Diagnosis Answers

| Question | Answer |
|----------|--------|
| Where is the string generated? | `chat-CGlveWq2.js` in compiled OpenClaw bundle, `buildOversizedHistoryPlaceholder()` |
| Is image stored as base64 in history? | YES — as `input_image` content block with full data URL |
| Is UI sending full chat history with image? | YES — on every turn |
| Is OpenClaw truncating history before multimodal request? | YES — replacing oversized messages (>128 KB) with placeholder |
| Is llama.cpp receiving actual image? | NO on 2nd+ turn — receives placeholder text instead |
| Why does Image Test endpoint work? | It bypasses chat history entirely — one-shot direct API call |
| Can we create dedicated image analysis mode? | YES — this is the recommended fix (see Fix Plan below) |
| Can images be stored by path in history? | NOT through current webchat path — requires compiled JS modification |
| Can safe history trimming be added? | YES — but trimming text history won't help; image messages must be excluded |
| What is the minimal patch? | Add a `/img` skill that routes images through the direct API path |

---

## Proposed Fix Plan

### Fix A — Dedicated `/img` Slash Command (RECOMMENDED)

**Risk: Very Low** — no modification to OpenClaw internals.

Create a custom OpenClaw skill `/img [prompt]` that:

1. Reads the most recently uploaded image from `~/.openclaw/media/inbound/`
2. Calls `http://127.0.0.1:18888/api/image-test` with the image data URL + prompt
3. Returns the analysis result as a text reply

**Why this works**:
- No image data enters chat history at all
- The skill result is TEXT ONLY — fits easily in history budget
- Reuses the already-working Model Control UI image test path
- Does not require any changes to compiled OpenClaw code

**Limitation**: User must upload image via the media inbound path, not drag-and-drop into webchat.

**Files to create**:
- A skill definition in `openclaw.json` under `skills`
- A shell script: `scripts/image-analyze-skill.sh`

### Fix B — Image-Aware Session Management (MEDIUM RISK)

When the current model supports images and the user is about to send a new image-bearing message, **clear the chat history first** using a short-context mode.

This can be done via:
1. Create a new session before each image analysis
2. Or configure a short-lived session that auto-clears after image analysis

**Downside**: Loses conversation context. User cannot ask follow-up questions referencing prior text discussion.

### Fix C — Reduce Context History Before Image (LOW RISK, PARTIAL FIX)

Reduce `gateway.webchat.chatHistoryMaxChars` to force more aggressive text trimming. This does NOT fix the image placeholder issue (image data is in bytes, not chars), but reduces the amount of context pollution from other oversized messages.

**Current**: `gateway.webchat.chatHistoryMaxChars: 50000`
**Proposed**: No change needed here — the image issue is bytes, not chars.

### Fix D — Modify Compiled Bundle (DO NOT DO)

Increase `CHAT_HISTORY_MAX_SINGLE_MESSAGE_BYTES` from 128 KB to something larger, like 8 MB. This would require editing the compiled minified JS bundle directly. Extremely fragile — breaks on any OpenClaw update. **NOT RECOMMENDED.**

---

## Recommended Immediate Action

**Implement Fix A** (dedicated `/img` slash command skill).

Full implementation plan is in `OPENCLAW_IMAGE_PIPELINE_FIX_PLAN.md`.

Do not implement until approved.

---

## Risk Assessment

| Fix | Risk | Reversible | Breaks Existing? |
|-----|------|-----------|-----------------|
| Fix A — `/img` skill | Very Low | Yes | No |
| Fix B — Session clear | Low | Yes | Minor UX change |
| Fix C — Reduce chat chars | Very Low | Yes | No |
| Fix D — Modify compiled JS | Very High | Hard | Yes |

---

## Additional Issue Found in Logs

During audit, the following error was found in `openclaw-gateway.service` logs:

```
error=LLM request failed: provider rejected the request schema or tool payload.
rawError=400 Failed to tokenize prompt
```

**Cause**: Embedded agent bootstraps AGENTS.md (13,666 chars), SOUL.md, TOOLS.md — these are injected into the prompt along with tool definitions. Gemma 4 llama.cpp returns 400 when the combined prompt+tools format is invalid. This is a separate issue from image analysis but may compound the problem.

**This is a separate issue and is NOT in scope for this investigation.** Document separately if needed.
