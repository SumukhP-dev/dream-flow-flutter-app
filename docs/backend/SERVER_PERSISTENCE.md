# Keeping the Server Running

This guide explains different methods to keep your Dream Flow backend server running persistently, even after closing the terminal or if it crashes.

## Quick Start

The easiest way is to use the helper script:

```bash
./run_server_persistent.sh
```

This will start the server in a `screen` session that persists across terminal closures.

## Methods Overview

| Method | Best For | Pros | Cons |
|--------|----------|------|------|
| **screen** | Quick setup, easy access | Simple, detachable, built-in | Need to remember session name |
| **tmux** | Power users, multiple windows | More features than screen | Slightly more complex |
| **nohup** | Simple background process | Very simple, logs to file | Harder to interact with |
| **systemd** | Production, auto-restart | Auto-restart, proper service | Requires systemd setup |

## Method 1: Screen (Recommended for Development)

### Start Server

```bash
# Start local API server
./run_server_persistent.sh --mode local --method screen

# Or start batch server
./run_server_persistent.sh --mode batch --method screen
```

### Manage Session

```bash
# List all screen sessions
screen -ls

# Attach to running session
screen -r dreamflow-api        # For local server
screen -r dreamflow-batch      # For batch server

# Detach from session (while inside)
# Press: Ctrl+A, then D

# Kill a session
screen -S dreamflow-api -X quit
```

## Method 2: Tmux

### Start Server

```bash
./run_server_persistent.sh --method tmux
```

### Manage Session

```bash
# List sessions
tmux ls

# Attach to session
tmux attach -t dreamflow-api

# Detach (while inside)
# Press: Ctrl+B, then D

# Kill session
tmux kill-session -t dreamflow-api
```

## Method 3: Nohup (Background Process)

### Start Server

```bash
./run_server_persistent.sh --method nohup
```

### Manage Process

```bash
# View logs
tail -f logs/server_*.log

# Find process ID
cat logs/server.pid

# Stop server
kill $(cat logs/server.pid)

# Or find and kill manually
ps aux | grep run_local_server
kill <PID>
```

## Method 4: Systemd User Service (Best for Production)

### Setup (One-time)

```bash
# Create service
./run_server_persistent.sh --method systemd

# Enable and start
systemctl --user daemon-reload
systemctl --user enable dreamflow-local.service
systemctl --user start dreamflow-local.service
```

### Manage Service

```bash
# Check status
systemctl --user status dreamflow-local.service

# View logs
journalctl --user -u dreamflow-local.service -f

# Stop
systemctl --user stop dreamflow-local.service

# Restart
systemctl --user restart dreamflow-local.service

# Disable (prevent auto-start)
systemctl --user disable dreamflow-local.service
```

### Enable Auto-Start on Boot

```bash
# Enable lingering (allows user services to run without login)
loginctl enable-linger $USER

# Service will now start automatically on boot
```

## Manual Methods

### Screen (Manual)

```bash
# Start new screen session
screen -S dreamflow-api

# Inside screen, run server
./run_local_server.sh

# Detach: Ctrl+A, then D
# Reattach: screen -r dreamflow-api
```

### Tmux (Manual)

```bash
# Start new tmux session
tmux new -s dreamflow-api

# Inside tmux, run server
./run_local_server.sh

# Detach: Ctrl+B, then D
# Reattach: tmux attach -t dreamflow-api
```

### Nohup (Manual)

```bash
# Start in background with logging
nohup ./run_local_server.sh > logs/server.log 2>&1 &

# View logs
tail -f logs/server.log

# Find and stop
ps aux | grep run_local_server
kill <PID>
```

## Checking if Server is Running

### Check Port

```bash
# Check if port 8080 is in use
lsof -i :8080
# or
netstat -tuln | grep 8080
```

### Check Process

```bash
# Find server process
ps aux | grep uvicorn
ps aux | grep run_local_server
```

### Test API

```bash
# Health check
curl http://localhost:8080/health

# Or in browser
open http://localhost:8080/docs
```

## Troubleshooting

### Server Won't Start

1. Check if port is already in use:
   ```bash
   lsof -i :8080
   ```

2. Check logs:
   ```bash
   # For screen/tmux: attach to session
   # For nohup: tail -f logs/server.log
   # For systemd: journalctl --user -u dreamflow-local.service
   ```

3. Check dependencies:
   ```bash
   source .venv/bin/activate
   pip install -r requirements.txt
   ```

### Server Keeps Crashing

1. Check system resources:
   ```bash
   free -h    # Check RAM
   df -h      # Check disk space
   ```

2. Check for errors in logs

3. Try reducing batch size or quality settings

### Can't Find Screen/Tmux Session

```bash
# List all sessions
screen -ls
tmux ls

# If session is "Attached", force detach first
screen -d dreamflow-api
tmux detach -s dreamflow-api
```

## Recommended Setup

**For Development:**
- Use `screen` or `tmux` for easy access and debugging

**For Production:**
- Use `systemd` user service for auto-restart and proper logging

**For Quick Testing:**
- Use `nohup` for simple background execution

## Example Workflow

```bash
# 1. Start server in screen
./run_server_persistent.sh

# 2. Detach and close terminal (server keeps running)

# 3. Later, reattach to check status
screen -r dreamflow-api

# 4. View logs, make changes, restart if needed

# 5. Detach again when done
```

## Auto-Restart on Crash

Only `systemd` method provides automatic restart on crashes. For other methods, you'll need to manually restart if the server crashes.

To enable auto-restart with systemd:

```bash
# The service file already includes:
# Restart=always
# RestartSec=10

# This means it will restart 10 seconds after any crash
```

