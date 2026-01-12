# =============================================================================
# Dream Flow Backend - Persistent Server Runner (Windows PowerShell)
# =============================================================================
# This script runs the server in a way that persists across terminal closures
# and can run in the background on Windows.
#
# Usage: .\run_server_persistent.ps1 [OPTIONS]
#
# Options:
#   --method task|service|background    Persistence method (default: task)
#   --help                             Show this help message
# =============================================================================

param(
    [string]$Method = "task",
    [switch]$Help
)

$ErrorActionPreference = "Stop"

# Colors for output
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

if ($Help) {
    Write-Output "Usage: .\run_server_persistent.ps1 [OPTIONS]"
    Write-Output ""
    Write-Output "Options:"
    Write-Output "  --method task|service|background    Persistence method (default: task)"
    Write-Output ""
    Write-Output "Methods:"
    Write-Output "  task        - Run as Windows Scheduled Task (survives logout)"
    Write-Output "  service     - Run as Windows Service (requires NSSM)"
    Write-Output "  background  - Run as PowerShell background job (survives terminal close)"
    Write-Output ""
    exit 0
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BackendDir = $ScriptDir
$LogsDir = Join-Path $BackendDir "logs"
New-Item -ItemType Directory -Force -Path $LogsDir | Out-Null

# Get the Python executable path
$PythonExe = Join-Path $BackendDir ".venv\Scripts\python.exe"
if (-not (Test-Path $PythonExe)) {
    Write-ColorOutput Red "Error: Python virtual environment not found at $PythonExe"
    Write-Output "Please run: python -m venv .venv"
    exit 1
}

# Build the command to run
$ServerCommand = "& `"$PythonExe`" -m uvicorn app.main:app --host 0.0.0.0 --port 8080"
$WorkingDir = $BackendDir

if ($Method -eq "task") {
    Write-ColorOutput Green "Setting up Windows Scheduled Task..."
    
    $TaskName = "DreamFlow-Backend"
    $TaskDescription = "Dream Flow Backend API Server"
    
    # Remove existing task if it exists
    $ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($ExistingTask) {
        Write-ColorOutput Yellow "Removing existing task..."
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    }
    
    # Create the action (command to run)
    $Action = New-ScheduledTaskAction -Execute "powershell.exe" `
        -Argument "-NoProfile -ExecutionPolicy Bypass -Command `"cd '$WorkingDir'; $ServerCommand`"" `
        -WorkingDirectory $WorkingDir
    
    # Create trigger (at startup)
    $Trigger = New-ScheduledTaskTrigger -AtStartup
    
    # Create settings
    $Settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -RestartCount 3 `
        -RestartInterval (New-TimeSpan -Minutes 1)
    
    # Create principal (run as current user)
    $Principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive
    
    # Register the task
    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $Action `
        -Trigger $Trigger `
        -Settings $Settings `
        -Principal $Principal `
        -Description $TaskDescription | Out-Null
    
    Write-ColorOutput Green "Scheduled task created: $TaskName"
    Write-Output ""
    Write-ColorOutput Yellow "To start the task:"
    Write-Output "  Start-ScheduledTask -TaskName `"$TaskName`""
    Write-Output ""
    Write-ColorOutput Yellow "To check status:"
    Write-Output "  Get-ScheduledTask -TaskName `"$TaskName`" | Get-ScheduledTaskInfo"
    Write-Output ""
    Write-ColorOutput Yellow "To stop the task:"
    Write-Output "  Stop-ScheduledTask -TaskName `"$TaskName`""
    Write-Output ""
    Write-ColorOutput Yellow "To remove the task:"
    Write-Output "  Unregister-ScheduledTask -TaskName `"$TaskName`" -Confirm:`$false"
    Write-Output ""
    
    $StartNow = Read-Host "Start the task now? (Y/N)"
    if ($StartNow -eq "Y" -or $StartNow -eq "y") {
        Start-ScheduledTask -TaskName $TaskName
        Write-ColorOutput Green "Task started!"
        Start-Sleep -Seconds 3
        $TaskInfo = Get-ScheduledTask -TaskName $TaskName | Get-ScheduledTaskInfo
        Write-Output "Status: $($TaskInfo.State)"
    }

} elseif ($Method -eq "service") {
    Write-ColorOutput Yellow "Windows Service method requires NSSM (Non-Sucking Service Manager)"
    Write-Output "Download from: https://nssm.cc/download"
    Write-Output ""
    Write-Output "After installing NSSM, run:"
    Write-Output "  nssm install DreamFlow-Backend `"$PythonExe`" `"-m uvicorn app.main:app --host 0.0.0.0 --port 8080`""
    Write-Output "  nssm set DreamFlow-Backend AppDirectory `"$WorkingDir`""
    Write-Output "  nssm start DreamFlow-Backend"

} elseif ($Method -eq "background") {
    Write-ColorOutput Green "Starting server as PowerShell background job..."
    
    $Job = Start-Job -ScriptBlock {
        param($WorkingDir, $PythonExe)
        Set-Location $WorkingDir
        & $PythonExe -m uvicorn app.main:app --host 0.0.0.0 --port 8080
    } -ArgumentList $WorkingDir, $PythonExe
    
    Write-ColorOutput Green "Server started as background job (ID: $($Job.Id))"
    Write-Output ""
    Write-ColorOutput Yellow "To check job status:"
    Write-Output "  Get-Job -Id $($Job.Id)"
    Write-Output ""
    Write-ColorOutput Yellow "To view output:"
    Write-Output "  Receive-Job -Id $($Job.Id)"
    Write-Output ""
    Write-ColorOutput Yellow "To stop the job:"
    Write-Output "  Stop-Job -Id $($Job.Id); Remove-Job -Id $($Job.Id)"
    Write-Output ""
    Write-ColorOutput Yellow "Note: Background jobs stop when PowerShell session closes"
    Write-ColorOutput Yellow "For persistence, use --method task instead"

} else {
    Write-ColorOutput Red "Unknown method: $Method"
    Write-Output "Available methods: task, service, background"
    exit 1
}

