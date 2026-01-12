#!/bin/bash
# =============================================================================
# Quick Story Generation Test (with timeout)
# =============================================================================

set -e

BASE_URL="${BASE_URL:-http://localhost:8080}"
TIMEOUT="${TIMEOUT:-180}"  # 3 minutes timeout

echo "=== Quick Story Generation Test ==="
echo "Base URL: ${BASE_URL}"
echo "Timeout: ${TIMEOUT}s"
echo ""

# Test with timeout
echo "Sending story generation request..."
echo "This may take 1-3 minutes depending on API response time..."
echo ""

timeout ${TIMEOUT} curl -X POST "${BASE_URL}/api/v1/story" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "A very short peaceful story about a sleepy kitten",
    "theme": "calm",
    "target_length": 100
  }' \
  -w "\n\nHTTP Status: %{http_code}\nTotal Time: %{time_total}s\n" \
  -v 2>&1 | tee /tmp/story_test.log

EXIT_CODE=$?

if [ $EXIT_CODE -eq 124 ]; then
    echo ""
    echo "❌ Request timed out after ${TIMEOUT} seconds"
    echo "The API might be slow or the request is hanging."
    echo ""
    echo "Possible causes:"
    echo "  1. Hugging Face API is slow/queued"
    echo "  2. Network issues"
    echo "  3. Model loading time"
    echo ""
    echo "Check server logs for more details."
elif [ $EXIT_CODE -eq 0 ]; then
    echo ""
    echo "✅ Request completed successfully!"
else
    echo ""
    echo "❌ Request failed with exit code: $EXIT_CODE"
    echo "Check /tmp/story_test.log for details"
fi

