# Dream Flow - Run Flutter Frontend Only
# Navigates to the Flutter app directory and runs it

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location "$scriptDir\dream-flow-app\app"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Dream Flow Flutter App" -ForegroundColor Green
Write-Host "Connecting to backend at http://localhost:8080" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

flutter run

