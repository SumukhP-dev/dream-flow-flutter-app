# Quick Fix for Server Startup

The server screen session is running but stuck because the virtual environment setup failed.

## Issue
The `python3-venv` package is not fully installed. You need to install the specific version for Python 3.12.

## Solution

Run these commands in your terminal:

```bash
sudo apt install -y python3.12-venv python3-pip screen
```

Then restart the server:

```bash
cd /home/sumukh-paspuleti/Documents/Dream_Flow_Flutter_App/backend_fastapi
./run_server_persistent.sh --method screen
```

## Alternative: Manual Setup

If you want to set up manually without the script:

```bash
cd /home/sumukh-paspuleti/Documents/Dream_Flow_Flutter_App/backend_fastapi

# Remove incomplete venv
rm -rf .venv

# Create venv (after installing python3.12-venv)
python3 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Start server in screen
screen -S dreamflow-api
source .venv/bin/activate
export LOCAL_INFERENCE=true
uvicorn app.main:app --host 0.0.0.0 --port 8080 --reload
# Detach: Ctrl+A then D
```

## Current Status

- Screen session: Stopped (was stuck)
- Virtual environment: Removed (was incomplete)
- Next step: Install packages and restart

