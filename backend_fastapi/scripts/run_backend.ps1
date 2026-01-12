# Dream Flow - Run Backend Server Only
# Navigates to the backend directory and starts the FastAPI server

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location "$scriptDir\backend_fastapi"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Dream Flow Backend Server" -ForegroundColor Green
Write-Host "Starting on http://localhost:8080" -ForegroundColor Cyan
Write-Host "API Docs: http://localhost:8080/docs" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

python -m uvicorn app.main:app --host 0.0.0.0 --port 8080 --reload

