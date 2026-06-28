#!/usr/bin/env bash
# 02_test_gemma_vlm_direct_llamacpp_api.sh
# Test Gemma VLM via direct llama.cpp /v1/chat/completions API.
# Read-only. Does not modify any configs.
set -euo pipefail

PORT=8080
MODEL="gemma-4-31B-it-Q4_K_M.gguf"
# 1x1 transparent PNG
TEST_PNG="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="

echo "=== Test: llama.cpp /v1/models ==="
curl -fsS --connect-timeout 3 --max-time 5 "http://127.0.0.1:${PORT}/v1/models" | python3 -m json.tool
echo ""

echo "=== Test: Image inference ==="
curl -fsS --connect-timeout 3 --max-time 60 \
  -X POST "http://127.0.0.1:${PORT}/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"${MODEL}\",
    \"messages\": [{\"role\": \"user\", \"content\": [
      {\"type\": \"text\", \"text\": \"Describe this image in one sentence.\"},
      {\"type\": \"image_url\", \"image_url\": {\"url\": \"${TEST_PNG}\"}}
    ]}],
    \"max_tokens\": 80,
    \"temperature\": 0.1
  }" | python3 -m json.tool
echo ""
echo "DONE"
