# Quick test runner for Dream Flow
# Usage: .\quick_test.ps1

Write-Host "=== Dream Flow Quick Test Runner ===" -ForegroundColor Cyan
Write-Host ""

# Set environment variables
$env:SUPABASE_URL = "https://dbpvmfglduprtbpaygmo.supabase.co"
$env:SUPABASE_ANON_KEY = "sb_secret_f7om8DHi_eeV89aYbwVJXQ_uc546iWP"
$env:BACKEND_URL = "http://10.0.2.2:8080"

Write-Host "Configuration:" -ForegroundColor Green
Write-Host "  SUPABASE_URL: $env:SUPABASE_URL"
Write-Host "  BACKEND_URL: $env:BACKEND_URL"
Write-Host ""

# Run unit tests
Write-Host "Running unit tests..." -ForegroundColor Yellow
flutter test test/session_screen_test.dart

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Unit tests passed" -ForegroundColor Green
} else {
    Write-Host "✗ Unit tests failed" -ForegroundColor Red
}

Write-Host ""

# Run integration tests (if device available)
Write-Host "Running integration tests..." -ForegroundColor Yellow
$devices = flutter devices
if ($devices -match "emulator|device") {
    flutter test integration_test/session_screen_test.dart `
        --dart-define=SUPABASE_URL=$env:SUPABASE_URL `
        --dart-define=SUPABASE_ANON_KEY=$env:SUPABASE_ANON_KEY `
        --dart-define=BACKEND_URL=$env:BACKEND_URL
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Integration tests passed" -ForegroundColor Green
    } else {
        Write-Host "✗ Integration tests failed" -ForegroundColor Red
    }
} else {
    Write-Host "⚠ No device/emulator found. Skipping integration tests." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Test Run Complete ===" -ForegroundColor Cyan

