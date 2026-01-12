# Dream Flow - Run App on Pixel 6
# This script helps avoid OneDrive sync issues

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Dream Flow - Pixel 6 Testing" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Set working directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$appDir = Join-Path $scriptDir "dream-flow-app\app"
Set-Location $appDir

Write-Host "Current directory: $appDir" -ForegroundColor Yellow
Write-Host ""

# Check if device is connected
Write-Host "Checking for connected devices..." -ForegroundColor Yellow
$devices = flutter devices 2>&1
if ($devices -match "35221JEGR17301") {
    Write-Host "✓ Pixel 6 detected!" -ForegroundColor Green
} else {
    Write-Host "⚠ Pixel 6 not found. Make sure it's connected via USB." -ForegroundColor Yellow
    Write-Host ""
    flutter devices
    exit 1
}

Write-Host ""
Write-Host "Running Flutter app on Pixel 6..." -ForegroundColor Yellow
Write-Host "Backend URL: http://localhost:8080 (via ADB port forwarding)" -ForegroundColor Yellow
Write-Host ""
Write-Host "Note: First build takes 5-10 minutes. Please be patient!" -ForegroundColor Cyan
Write-Host ""

# Run the app
flutter run -d 35221JEGR17301 --dart-define=BACKEND_URL=http://localhost:8080































