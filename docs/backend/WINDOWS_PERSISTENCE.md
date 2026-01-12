# Running Servers Persistently on Windows

## Downtime Concerns

When running servers on your laptop, you may face downtime when:
- Laptop goes to sleep/hibernates
- Laptop is closed
- Terminal window is closed
- System reboots
- Laptop battery dies

## Solutions for Windows

### Option 1: Windows Scheduled Task (Recommended) ⭐

**Best for**: Auto-start on boot, survives logout, auto-restart on crash

```powershell
# Run the setup script
cd backend_fastapi
.\run_server_persistent.ps1 --method task
```

**Features:**
- ✅ Starts automatically when Windows boots
- ✅ Runs even when you're logged out
- ✅ Auto-restarts if server crashes (up to 3 times)
- ✅ Runs on battery power
- ✅ Easy to manage via Task Scheduler

**Manage the task:**
```powershell
# Check status
Get-ScheduledTask -TaskName "DreamFlow-Backend" | Get-ScheduledTaskInfo

# Start manually
Start-ScheduledTask -TaskName "DreamFlow-Backend"

# Stop
Stop-ScheduledTask -TaskName "DreamFlow-Backend"

# Remove
Unregister-ScheduledTask -TaskName "DreamFlow-Backend" -Confirm:$false
```

### Option 2: PowerShell Background Job

**Best for**: Quick testing, survives terminal close (but not PowerShell exit)

```powershell
cd backend_fastapi
.\run_server_persistent.ps1 --method background
```

**Limitations:**
- ❌ Stops when PowerShell session closes
- ❌ Doesn't survive reboot
- ✅ Survives terminal window close

### Option 3: Windows Service (Advanced)

**Best for**: Production, maximum reliability

Requires NSSM (Non-Sucking Service Manager):
1. Download from https://nssm.cc/download
2. Extract to a folder (e.g., `C:\nssm`)
3. Run:

```powershell
cd backend_fastapi
$PythonExe = "C:\path\to\backend_fastapi\.venv\Scripts\python.exe"
$WorkingDir = "C:\path\to\backend_fastapi"

C:\nssm\nssm.exe install DreamFlow-Backend "$PythonExe" "-m uvicorn app.main:app --host 0.0.0.0 --port 8080"
C:\nssm\nssm.exe set DreamFlow-Backend AppDirectory "$WorkingDir"
C:\nssm\nssm.exe set DreamFlow-Backend AppStdout "$WorkingDir\logs\stdout.log"
C:\nssm\nssm.exe set DreamFlow-Backend AppStderr "$WorkingDir\logs\stderr.log"
C:\nssm\nssm.exe set DreamFlow-Backend AppRestartDelay 10000
C:\nssm\nssm.exe start DreamFlow-Backend
```

**Manage service:**
```powershell
# Start
C:\nssm\nssm.exe start DreamFlow-Backend

# Stop
C:\nssm\nssm.exe stop DreamFlow-Backend

# Restart
C:\nssm\nssm.exe restart DreamFlow-Backend

# Remove
C:\nssm\nssm.exe remove DreamFlow-Backend confirm
```

## Preventing Sleep/Hibernate

To keep servers running when laptop lid is closed:

### Windows Power Settings

1. Open **Power Options** (Control Panel → Power Options)
2. Click **"Choose what closing the lid does"**
3. Set **"When I close the lid"** to **"Do nothing"** for both:
   - On battery
   - Plugged in
4. Set **"When I press the power button"** to **"Do nothing"** (optional)

**Or via PowerShell:**
```powershell
# Prevent sleep when lid is closed (plugged in)
powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 0

# Prevent sleep when lid is closed (on battery) - WARNING: drains battery
powercfg /setdcvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 0

# Apply changes
powercfg /setactive SCHEME_CURRENT
```

## Comparison: Laptop vs Remote Server

| Feature | Your Laptop | Remote Server |
|---------|-------------|---------------|
| **Uptime** | Depends on laptop being on | 24/7 (if configured) |
| **Latency** | Very low (localhost) | Network dependent |
| **Cost** | Free (uses your hardware) | Monthly hosting fees |
| **Control** | Full control | Limited access |
| **Maintenance** | Manual | Can be automated |
| **Sleep/Hibernate** | Can cause downtime | Not applicable |
| **Power** | Battery/AC dependent | Always on |
| **Best For** | Development, personal use | Production, 24/7 access |

## Recommended Setup for Your Laptop

1. **Use Scheduled Task** (Option 1) for auto-start
2. **Configure power settings** to prevent sleep when plugged in
3. **Keep laptop plugged in** when you want servers running
4. **Use Task Scheduler** to auto-start on boot

## Quick Setup Commands

```powershell
# 1. Set up scheduled task
cd backend_fastapi
.\run_server_persistent.ps1 --method task

# 2. Prevent sleep when plugged in (optional)
powercfg /change standby-timeout-ac 0

# 3. Check if servers are running
netstat -ano | findstr ":8080 :3000"
```

## Monitoring

```powershell
# Check backend status
Invoke-WebRequest -Uri http://localhost:8080/health -UseBasicParsing

# View scheduled task status
Get-ScheduledTask -TaskName "DreamFlow-Backend" | Get-ScheduledTaskInfo

# Check if processes are running
Get-Process | Where-Object {$_.ProcessName -like "*python*" -or $_.ProcessName -like "*node*"}
```

## Troubleshooting

### Server stops when laptop sleeps
- **Solution**: Configure power settings to prevent sleep (see above)
- **Alternative**: Use "Do nothing" when lid closes

### Server doesn't start on boot
- **Solution**: Check Task Scheduler → ensure task is enabled
- **Check**: Task must be set to "Run whether user is logged on or not"

### Server crashes and doesn't restart
- **Solution**: Scheduled Task has auto-restart (3 attempts)
- **Check**: View task history in Task Scheduler

### Can't access server from other devices
- **Solution**: Ensure firewall allows port 8080
- **Command**: `New-NetFirewallRule -DisplayName "Dream Flow Backend" -Direction Inbound -LocalPort 8080 -Protocol TCP -Action Allow`

