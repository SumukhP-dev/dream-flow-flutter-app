#!/bin/bash
# =============================================================================
# Dream Flow Backend - Local Server Startup Script
# =============================================================================
# This script sets up and runs the backend in local inference mode,
# optimized for CPU-only systems with limited RAM.
#
# Usage: ./run_local_server.sh [--download-only] [--help]
#
# Options:
#   --download-only    Only download the model, don't start the server
#   --help             Show this help message
# =============================================================================

set -e

# Configuration
MODEL_DIR="./models"
MODEL_FILE="tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"
MODEL_URL="https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/${MODEL_FILE}"
MODEL_PATH="${MODEL_DIR}/${MODEL_FILE}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print banner
echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           Dream Flow Backend - Local Server Mode             ║"
echo "║        CPU-Optimized for TinyLlama + Edge-TTS                ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Parse arguments
DOWNLOAD_ONLY=false
for arg in "$@"; do
    case $arg in
        --download-only)
            DOWNLOAD_ONLY=true
            shift
            ;;
        --help)
            echo "Usage: ./run_local_server.sh [--download-only] [--help]"
            echo ""
            echo "Options:"
            echo "  --download-only    Only download the model, don't start the server"
            echo "  --help             Show this help message"
            echo ""
            echo "Environment Variables:"
            echo "  LOCAL_INFERENCE    Set to 'true' to enable local inference (default: true)"
            echo "  LOCAL_IMAGES       Set to 'true' for placeholder images (default: true)"
            echo "  EDGE_TTS_VOICE     Voice for TTS (default: en-US-AriaNeural)"
            echo "  PORT               Server port (default: 8080)"
            exit 0
            ;;
    esac
done

# Check for Python
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: Python 3 is required but not found.${NC}"
    exit 1
fi

# Check for virtual environment
if [ ! -d ".venv" ]; then
    echo -e "${YELLOW}Creating virtual environment...${NC}"
    python3 -m venv .venv
fi

# Activate virtual environment
echo -e "${GREEN}Activating virtual environment...${NC}"
source .venv/bin/activate

# Install dependencies if needed
if ! python3 -c "import llama_cpp" &> /dev/null || ! python3 -c "import edge_tts" &> /dev/null; then
    echo -e "${YELLOW}Installing dependencies...${NC}"
    pip install --upgrade pip
    pip install -r requirements.txt
    
    # llama-cpp-python might need special build flags for CPU optimization
    echo -e "${YELLOW}Installing llama-cpp-python with CPU optimizations...${NC}"
    CMAKE_ARGS="-DLLAMA_BLAS=ON -DLLAMA_BLAS_VENDOR=OpenBLAS" pip install llama-cpp-python --force-reinstall --no-cache-dir 2>/dev/null || \
    pip install llama-cpp-python --force-reinstall --no-cache-dir
fi

# Create models directory
mkdir -p "${MODEL_DIR}"

# Download model if not present
if [ ! -f "${MODEL_PATH}" ]; then
    echo -e "${YELLOW}Downloading TinyLlama model (~600MB)...${NC}"
    echo -e "${BLUE}This is a one-time download.${NC}"
    
    # Check for wget or curl
    if command -v wget &> /dev/null; then
        wget --progress=bar:force:noscroll -O "${MODEL_PATH}" "${MODEL_URL}"
    elif command -v curl &> /dev/null; then
        curl -L --progress-bar -o "${MODEL_PATH}" "${MODEL_URL}"
    else
        echo -e "${RED}Error: wget or curl is required to download the model.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Model downloaded successfully!${NC}"
else
    echo -e "${GREEN}Model already downloaded: ${MODEL_PATH}${NC}"
fi

# Exit if download-only mode
if [ "$DOWNLOAD_ONLY" = true ]; then
    echo -e "${GREEN}Model download complete. Exiting.${NC}"
    exit 0
fi

# Create .env.local if it doesn't exist
if [ ! -f ".env.local" ]; then
    echo -e "${YELLOW}Creating .env.local configuration...${NC}"
    cat > .env.local << EOF
# Local Inference Configuration
LOCAL_INFERENCE=true
LOCAL_MODEL_PATH=${MODEL_PATH}
LOCAL_IMAGES=true
EDGE_TTS_VOICE=en-US-AriaNeural

# Server Configuration
BACKEND_URL=http://localhost:8080

# Copy your Supabase credentials from .env
# SUPABASE_URL=your-supabase-url
# SUPABASE_ANON_KEY=your-anon-key
# SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# Optional: Keep HuggingFace token for image generation fallback
# HUGGINGFACE_API_TOKEN=hf_...
EOF
    echo -e "${YELLOW}Please edit .env.local with your Supabase credentials.${NC}"
fi

# Export environment variables for local mode
export LOCAL_INFERENCE=true
export LOCAL_MODEL_PATH="${MODEL_PATH}"
export LOCAL_IMAGES=true
export EDGE_TTS_VOICE="${EDGE_TTS_VOICE:-en-US-AriaNeural}"

# Load .env and .env.local
if [ -f ".env" ]; then
    set -a
    source .env
    set +a
fi
if [ -f ".env.local" ]; then
    set -a
    source .env.local
    set +a
fi

# Get port from environment or use default
PORT="${PORT:-8080}"

# Display configuration
echo ""
echo -e "${BLUE}Configuration:${NC}"
echo -e "  Model:      TinyLlama 1.1B (${MODEL_FILE})"
echo -e "  TTS:        Edge-TTS (${EDGE_TTS_VOICE})"
echo -e "  Images:     $([ "$LOCAL_IMAGES" = "true" ] && echo "Placeholder images" || echo "Cloud API")"
echo -e "  Port:       ${PORT}"
echo ""

# Check for required environment variables
if [ -z "$SUPABASE_SERVICE_ROLE_KEY" ]; then
    echo -e "${RED}Warning: SUPABASE_SERVICE_ROLE_KEY is not set.${NC}"
    echo -e "${YELLOW}The server may fail to start without proper Supabase configuration.${NC}"
    echo -e "${YELLOW}Please set your credentials in .env or .env.local${NC}"
    echo ""
fi

# Start the server
echo -e "${GREEN}Starting Dream Flow backend server...${NC}"
echo -e "${BLUE}Server will be available at: http://localhost:${PORT}${NC}"
echo -e "${BLUE}API documentation at: http://localhost:${PORT}/docs${NC}"
echo ""

# Run uvicorn with optimized settings for local development
exec uvicorn app.main:app \
    --host 0.0.0.0 \
    --port "${PORT}" \
    --reload \
    --workers 1 \
    --timeout-keep-alive 120

