#!/bin/bash
# =============================================================================
# Test Backend Server
# =============================================================================

set -e

BASE_URL="${BASE_URL:-http://localhost:8080}"
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Testing Dream Flow Backend Server ===${NC}"
echo -e "Base URL: ${BASE_URL}"
echo ""

# Test 1: Health Check
echo -e "${YELLOW}Test 1: Health Check${NC}"
HEALTH_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" "${BASE_URL}/health")
HTTP_CODE=$(echo "$HEALTH_RESPONSE" | grep "HTTP_CODE" | cut -d: -f2)
BODY=$(echo "$HEALTH_RESPONSE" | sed '/HTTP_CODE/d')

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ Health check passed${NC}"
    echo "Response: $BODY"
else
    echo -e "${RED}✗ Health check failed (HTTP $HTTP_CODE)${NC}"
    echo "Response: $BODY"
    exit 1
fi
echo ""

# Test 2: API Documentation
echo -e "${YELLOW}Test 2: API Documentation${NC}"
DOCS_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" "${BASE_URL}/docs")
HTTP_CODE=$(echo "$DOCS_RESPONSE" | grep "HTTP_CODE" | cut -d: -f2)

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ API docs available at ${BASE_URL}/docs${NC}"
else
    echo -e "${YELLOW}⚠ API docs not accessible (HTTP $HTTP_CODE)${NC}"
fi
echo ""

# Test 3: Story Generation (if HUGGINGFACE_API_TOKEN is set)
if [ -n "$HUGGINGFACE_API_TOKEN" ] || [ -f ".env" ]; then
    echo -e "${YELLOW}Test 3: Story Generation${NC}"
    echo "Sending story generation request..."
    
    STORY_PAYLOAD='{
        "prompt": "A peaceful bedtime story about a sleepy kitten",
        "theme": "calm",
        "user_profile": {
            "age": 5,
            "interests": ["animals", "nature"],
            "preferred_length": "short"
        }
    }'
    
    STORY_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
        -X POST "${BASE_URL}/api/v1/story" \
        -H "Content-Type: application/json" \
        -d "$STORY_PAYLOAD")
    
    HTTP_CODE=$(echo "$STORY_RESPONSE" | grep "HTTP_CODE" | cut -d: -f2)
    BODY=$(echo "$STORY_RESPONSE" | sed '/HTTP_CODE/d')
    
    if [ "$HTTP_CODE" = "200" ]; then
        echo -e "${GREEN}✓ Story generation successful${NC}"
        echo "Story preview:"
        echo "$BODY" | python3 -m json.tool 2>/dev/null | head -20 || echo "$BODY" | head -5
    elif [ "$HTTP_CODE" = "503" ]; then
        echo -e "${YELLOW}⚠ Story generation returned 503 (service unavailable)${NC}"
        echo "This might be expected if using local inference without models"
        echo "Response: $BODY"
    else
        echo -e "${RED}✗ Story generation failed (HTTP $HTTP_CODE)${NC}"
        echo "Response: $BODY"
    fi
else
    echo -e "${YELLOW}Test 3: Story Generation (skipped)${NC}"
    echo "HUGGINGFACE_API_TOKEN not set or .env not found"
fi
echo ""

# Test 4: Presets Endpoint
echo -e "${YELLOW}Test 4: Story Presets${NC}"
PRESETS_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" "${BASE_URL}/api/v1/presets")
HTTP_CODE=$(echo "$PRESETS_RESPONSE" | grep "HTTP_CODE" | cut -d: -f2)
BODY=$(echo "$PRESETS_RESPONSE" | sed '/HTTP_CODE/d')

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ Presets endpoint working${NC}"
    echo "Response preview:"
    echo "$BODY" | python3 -m json.tool 2>/dev/null | head -10 || echo "$BODY" | head -3
else
    echo -e "${YELLOW}⚠ Presets endpoint returned HTTP $HTTP_CODE${NC}"
fi
echo ""

echo -e "${GREEN}=== Testing Complete ===${NC}"
echo ""
echo "For interactive API testing, visit: ${BASE_URL}/docs"

