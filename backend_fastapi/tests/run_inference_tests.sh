#!/bin/bash
#
# Quick test runner for AI inference integration tests
#
# Usage:
#   ./run_inference_tests.sh           # Run all tests
#   ./run_inference_tests.sh cloud     # Test cloud only
#   ./run_inference_tests.sh local     # Test local only
#   ./run_inference_tests.sh fallback  # Test fallback only
#   ./run_inference_tests.sh e2e       # Run standalone E2E script

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BACKEND_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}AI Inference Integration Tests${NC}"
echo -e "${BLUE}======================================${NC}\n"

# Check for HuggingFace token
if [ -z "$HUGGINGFACE_API_TOKEN" ]; then
    echo -e "${YELLOW}⚠️  HUGGINGFACE_API_TOKEN not set. Cloud tests will be skipped.${NC}"
    echo -e "${YELLOW}   Set with: export HUGGINGFACE_API_TOKEN=hf_your_token${NC}\n"
fi

# Check for local model
MODEL_PATH="$BACKEND_DIR/models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"
if [ ! -f "$MODEL_PATH" ]; then
    echo -e "${YELLOW}⚠️  Local model not found at $MODEL_PATH${NC}"
    echo -e "${YELLOW}   Local tests will be skipped. Download with:${NC}"
    echo -e "${YELLOW}   cd $BACKEND_DIR/models${NC}"
    echo -e "${YELLOW}   wget https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf${NC}\n"
fi

# Change to backend directory
cd "$BACKEND_DIR"

# Check for pytest
if ! command -v pytest &> /dev/null; then
    echo -e "${RED}❌ pytest not found. Install with: pip install pytest pytest-asyncio${NC}"
    exit 1
fi

# Run tests based on argument
case "${1:-all}" in
    cloud)
        echo -e "${GREEN}Running cloud inference tests...${NC}\n"
        AI_INFERENCE_MODE=cloud_only pytest tests/test_inference_modes_integration.py::TestCloudInferenceMode -v -s
        ;;
    
    local)
        echo -e "${GREEN}Running local inference tests...${NC}\n"
        AI_INFERENCE_MODE=server_only pytest tests/test_inference_modes_integration.py::TestLocalInferenceMode -v -s
        ;;
    
    fallback)
        echo -e "${GREEN}Running fallback tests...${NC}\n"
        AI_INFERENCE_MODE=cloud_first pytest tests/test_inference_modes_integration.py::TestFallbackBehavior -v -s
        ;;
    
    e2e)
        echo -e "${GREEN}Running standalone E2E tests...${NC}\n"
        python tests/test_inference_e2e.py
        ;;
    
    all|*)
        echo -e "${GREEN}Running all integration tests...${NC}\n"
        pytest tests/test_inference_modes_integration.py -v -s
        ;;
esac

# Check exit code
if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}✅ Tests completed successfully!${NC}"
else
    echo -e "\n${RED}❌ Some tests failed. Check output above for details.${NC}"
    exit 1
fi
