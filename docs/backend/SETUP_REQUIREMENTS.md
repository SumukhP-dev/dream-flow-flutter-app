# Server Setup Requirements

Before running the persistent server, you need to install a few system packages.

## Quick Setup

Run these commands to install required packages:

```bash
sudo apt update
sudo apt install -y screen python3-venv python3-pip
```

## What Each Package Does

- **screen**: Terminal multiplexer for persistent sessions
- **python3-venv**: Creates Python virtual environments
- **python3-pip**: Python package installer

## After Installation

Once installed, you can run:

```bash
cd backend_fastapi
./run_server_persistent.sh --method screen
```

## Alternative: Use Nohup (No Screen Required)

If you don't want to install screen, you can use nohup instead:

```bash
cd backend_fastapi
./run_server_persistent.sh --method nohup
```

This doesn't require any additional packages.

## Manual Setup Steps

If you prefer to set up manually:

1. **Install packages:**
   ```bash
   sudo apt update
   sudo apt install -y python3-venv python3-pip
   ```

2. **Create virtual environment:**
   ```bash
   cd backend_fastapi
   python3 -m venv .venv
   source .venv/bin/activate
   pip install -r requirements.txt
   ```

3. **Run server with nohup:**
   ```bash
   mkdir -p logs
   nohup bash run_local_server.sh > logs/server.log 2>&1 &
   echo $! > logs/server.pid
   ```

4. **Check if running:**
   ```bash
   tail -f logs/server.log
   # or
   ps aux | grep uvicorn
   ```

5. **Stop server:**
   ```bash
   kill $(cat logs/server.pid)
   ```

