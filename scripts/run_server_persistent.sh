#!/bin/bash
# =============================================================================
# Dream Flow Backend - Persistent Server Runner
# =============================================================================
# This script runs the server in a way that persists across terminal closures
# and automatically restarts on crashes.
#
# Usage: ./run_server_persistent.sh [OPTIONS]
#
# Options:
#   --mode local|batch    Server mode (default: local)
#   --method screen|tmux|nohup|systemd    Persistence method (default: screen)
#   --help                Show this help message
# =============================================================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Defaults
MODE="local"
METHOD="screen"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --mode)
            MODE="$2"
            shift 2
            ;;
        --method)
            METHOD="$2"
            shift 2
            ;;
        --help)
            echo "Usage: ./run_server_persistent.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --mode local|batch     Server mode (default: local)"
            echo "  --method screen|tmux|nohup|systemd    Persistence method (default: screen)"
            echo ""
            echo "Examples:"
            echo "  ./run_server_persistent.sh                    # Local server in screen"
            echo "  ./run_server_persistent.sh --mode batch       # Batch server in screen"
            echo "  ./run_server_persistent.sh --method tmux       # Use tmux instead"
            echo "  ./run_server_persistent.sh --method nohup     # Background with nohup"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Determine script to run
if [ "$MODE" = "batch" ]; then
    SERVER_SCRIPT=""
    SESSION_NAME="dreamflow-batch"
else
    SERVER_SCRIPT="./run_local_server.sh"
    SESSION_NAME="dreamflow-api"
fi

# Check if script exists
if [ ! -f "$SERVER_SCRIPT" ]; then
    echo -e "${RED}Error: $SERVER_SCRIPT not found${NC}"
    exit 1
fi

# Method: screen
if [ "$METHOD" = "screen" ]; then
    if ! command -v screen &> /dev/null; then
        echo -e "${YELLOW}Installing screen...${NC}"
        sudo apt-get update && sudo apt-get install -y screen
    fi
    
    # Check if session already exists
    if screen -list | grep -q "$SESSION_NAME"; then
        echo -e "${YELLOW}Session $SESSION_NAME already exists.${NC}"
        echo -e "${BLUE}Attach with: screen -r $SESSION_NAME${NC}"
        echo -e "${BLUE}Or kill with: screen -S $SESSION_NAME -X quit${NC}"
        read -p "Kill existing session and start new? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            screen -S "$SESSION_NAME" -X quit || true
        else
            exit 0
        fi
    fi
    
    echo -e "${GREEN}Starting server in screen session: $SESSION_NAME${NC}"
    echo -e "${BLUE}Detach with: Ctrl+A then D${NC}"
    echo -e "${BLUE}Reattach with: screen -r $SESSION_NAME${NC}"
    echo ""
    
    screen -dmS "$SESSION_NAME" bash -c "$SERVER_SCRIPT; exec bash"
    sleep 2
    
    if screen -list | grep -q "$SESSION_NAME"; then
        echo -e "${GREEN}Server started successfully!${NC}"
        echo -e "${BLUE}Attach to session: screen -r $SESSION_NAME${NC}"
    else
        echo -e "${RED}Failed to start server${NC}"
        exit 1
    fi

# Method: tmux
elif [ "$METHOD" = "tmux" ]; then
    if ! command -v tmux &> /dev/null; then
        echo -e "${YELLOW}Installing tmux...${NC}"
        sudo apt-get update && sudo apt-get install -y tmux
    fi
    
    # Check if session exists
    if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        echo -e "${YELLOW}Session $SESSION_NAME already exists.${NC}"
        echo -e "${BLUE}Attach with: tmux attach -t $SESSION_NAME${NC}"
        read -p "Kill existing session and start new? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            tmux kill-session -t "$SESSION_NAME" || true
        else
            exit 0
        fi
    fi
    
    echo -e "${GREEN}Starting server in tmux session: $SESSION_NAME${NC}"
    echo -e "${BLUE}Detach with: Ctrl+B then D${NC}"
    echo -e "${BLUE}Reattach with: tmux attach -t $SESSION_NAME${NC}"
    echo ""
    
    tmux new-session -d -s "$SESSION_NAME" "$SERVER_SCRIPT"
    
    echo -e "${GREEN}Server started successfully!${NC}"
    echo -e "${BLUE}Attach to session: tmux attach -t $SESSION_NAME${NC}"

# Method: nohup
elif [ "$METHOD" = "nohup" ]; then
    LOG_FILE="./logs/server_$(date +%Y%m%d_%H%M%S).log"
    mkdir -p ./logs
    
    echo -e "${GREEN}Starting server in background with nohup...${NC}"
    echo -e "${BLUE}Logs: $LOG_FILE${NC}"
    echo ""
    
    nohup bash "$SERVER_SCRIPT" > "$LOG_FILE" 2>&1 &
    PID=$!
    
    echo -e "${GREEN}Server started with PID: $PID${NC}"
    echo -e "${BLUE}View logs: tail -f $LOG_FILE${NC}"
    echo -e "${BLUE}Stop server: kill $PID${NC}"
    echo "$PID" > ./logs/server.pid

# Method: systemd (user service)
elif [ "$METHOD" = "systemd" ]; then
    echo -e "${GREEN}Creating systemd user service...${NC}"
    
    SERVICE_NAME="dreamflow-${MODE}.service"
    SERVICE_FILE="$HOME/.config/systemd/user/$SERVICE_NAME"
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    
    mkdir -p "$HOME/.config/systemd/user"
    
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Dream Flow Backend ($MODE mode)
After=network.target

[Service]
Type=simple
WorkingDirectory=$SCRIPT_DIR
ExecStart=$SCRIPT_DIR/$SERVER_SCRIPT
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF
    
    echo -e "${GREEN}Service file created: $SERVICE_FILE${NC}"
    echo ""
    echo -e "${YELLOW}To enable and start:${NC}"
    echo -e "  systemctl --user daemon-reload"
    echo -e "  systemctl --user enable $SERVICE_NAME"
    echo -e "  systemctl --user start $SERVICE_NAME"
    echo ""
    echo -e "${YELLOW}To check status:${NC}"
    echo -e "  systemctl --user status $SERVICE_NAME"
    echo ""
    echo -e "${YELLOW}To view logs:${NC}"
    echo -e "  journalctl --user -u $SERVICE_NAME -f"
    echo ""
    echo -e "${YELLOW}To stop:${NC}"
    echo -e "  systemctl --user stop $SERVICE_NAME"
    
    read -p "Enable and start service now? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        systemctl --user daemon-reload
        systemctl --user enable "$SERVICE_NAME"
        systemctl --user start "$SERVICE_NAME"
        echo -e "${GREEN}Service started!${NC}"
    fi

else
    echo -e "${RED}Unknown method: $METHOD${NC}"
    echo "Available methods: screen, tmux, nohup, systemd"
    exit 1
fi

