#!/bin/bash
# =============================================================================
# Restart Backend Server (After Hugging Face Fix)
# =============================================================================

set -e

echo "=== Restarting Backend Server ==="
echo ""

# Find and kill existing uvicorn processes
echo "Stopping existing server..."
pkill -f "uvicorn.*main:app" || echo "No existing server found"

sleep 2

# Activate virtual environment
if [ -d ".venv" ]; then
    source .venv/bin/activate
    echo "✓ Virtual environment activated"
else
    echo "⚠ Warning: .venv not found, using system Python"
fi

# Check if huggingface_hub is updated
echo ""
echo "Checking huggingface_hub version..."
pip show huggingface_hub | grep Version || echo "huggingface_hub not installed"

echo ""
echo "=== Starting Backend Server ==="
echo "Server will start on http://localhost:8080"
echo "Press Ctrl+C to stop"
echo ""

# Start the server
uvicorn app.main:app --reload --port 8080

