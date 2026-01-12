# Dream Flow - Run Frontend and Backend in Foreground
# Opens two separate terminal windows for backend and frontend

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Dream Flow - Starting Services" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Start Backend in new window
Write-Host "Starting backend server in new window..." -ForegroundColor Yellow
$backendScript = @"
cd '$scriptDir\backend_fastapi'
Write-Host 'Dream Flow Backend Server' -ForegroundColor Green
Write-Host 'Starting on http://localhost:8080' -ForegroundColor Cyan
Write-Host ''
python -m uvicorn app.main:app --host 0.0.0.0 --port 8080 --reload
pause
"@

$backendScriptPath = Join-Path $env:TEMP "dreamflow_backend.ps1"
$backendScript | Out-File -FilePath $backendScriptPath -Encoding UTF8
Start-Process powershell -ArgumentList "-NoExit", "-File", $backendScriptPath

# Wait a moment for backend to start
Start-Sleep -Seconds 2

# Start Frontend in new window
Write-Host "Starting Flutter app in new window..." -ForegroundColor Yellow
$frontendScript = @"
cd '$scriptDir\dream-flow-app\app'
Write-Host 'Dream Flow Flutter App' -ForegroundColor Green
Write-Host 'Connecting to backend at http://localhost:8080' -ForegroundColor Cyan
Write-Host ''
flutter run
pause
"@

$frontendScriptPath = Join-Path $env:TEMP "dreamflow_frontend.ps1"
$frontendScript | Out-File -FilePath $frontendScriptPath -Encoding UTF8
Start-Process powershell -ArgumentList "-NoExit", "-File", $frontendScriptPath

Write-Host ""
Write-Host "✓ Backend and Frontend started in separate windows" -ForegroundColor Green
Write-Host ""
Write-Host "Backend: http://localhost:8080" -ForegroundColor Cyan
Write-Host "API Docs: http://localhost:8080/docs" -ForegroundColor Cyan
Write-Host ""
Write-Host "Press any key to exit this script (services will continue running)..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

