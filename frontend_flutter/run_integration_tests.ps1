# PowerShell script to run Flutter integration tests
# Usage: .\run_integration_tests.ps1

param(
    [string]$DeviceId = "emulator-5554",
    [switch]$AllTests = $false
)

Write-Host "=== Dream Flow Integration Tests ===" -ForegroundColor Cyan
Write-Host ""

# Check if Flutter is available
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "Error: Flutter is not in PATH" -ForegroundColor Red
    exit 1
}

# Check if device is available
Write-Host "Checking for device: $DeviceId" -ForegroundColor Yellow
$devices = flutter devices
if ($devices -notmatch $DeviceId) {
    Write-Host "Warning: Device $DeviceId not found. Available devices:" -ForegroundColor Yellow
    flutter devices
    Write-Host ""
    Write-Host "Attempting to continue anyway..." -ForegroundColor Yellow
}

# Set environment variables for tests
$env:SUPABASE_URL = "https://dbpvmfglduprtbpaygmo.supabase.co"
$env:SUPABASE_ANON_KEY = "sb_secret_f7om8DHi_eeV89aYbwVJXQ_uc546iWP"
$env:BACKEND_URL = "http://10.0.2.2:8080"

Write-Host "Configuration:" -ForegroundColor Green
Write-Host "  SUPABASE_URL: $env:SUPABASE_URL"
Write-Host "  BACKEND_URL: $env:BACKEND_URL"
Write-Host ""

# Get test files
$testFiles = @(
    "integration_test/app_test.dart",
    "integration_test/auth_test.dart",
    "integration_test/session_screen_test.dart",
    "integration_test/home_screen_test.dart"
)

$results = @()

foreach ($testFile in $testFiles) {
    if (Test-Path $testFile) {
        Write-Host "Running: $testFile" -ForegroundColor Cyan
        Write-Host "----------------------------------------" -ForegroundColor Gray
        
        try {
            $output = flutter test `
                --dart-define=SUPABASE_URL=$env:SUPABASE_URL `
                --dart-define=SUPABASE_ANON_KEY=$env:SUPABASE_ANON_KEY `
                --dart-define=BACKEND_URL=$env:BACKEND_URL `
                $testFile 2>&1
            
            $exitCode = $LASTEXITCODE
            
            if ($exitCode -eq 0) {
                Write-Host "✓ PASSED: $testFile" -ForegroundColor Green
                $results += @{File=$testFile; Status="PASSED"}
            } else {
                Write-Host "✗ FAILED: $testFile" -ForegroundColor Red
                $results += @{File=$testFile; Status="FAILED"}
                Write-Host $output
            }
        } catch {
            Write-Host "✗ ERROR: $testFile" -ForegroundColor Red
            Write-Host $_.Exception.Message
            $results += @{File=$testFile; Status="ERROR"}
        }
        
        Write-Host ""
    } else {
        Write-Host "⚠ SKIPPED: $testFile (not found)" -ForegroundColor Yellow
        $results += @{File=$testFile; Status="SKIPPED"}
    }
}

# Summary
Write-Host "=== Test Summary ===" -ForegroundColor Cyan
$passed = ($results | Where-Object { $_.Status -eq "PASSED" }).Count
$failed = ($results | Where-Object { $_.Status -eq "FAILED" }).Count
$errors = ($results | Where-Object { $_.Status -eq "ERROR" }).Count
$skipped = ($results | Where-Object { $_.Status -eq "SKIPPED" }).Count

Write-Host "Passed:  $passed" -ForegroundColor Green
Write-Host "Failed:  $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" })
Write-Host "Errors:  $errors" -ForegroundColor $(if ($errors -gt 0) { "Red" } else { "Green" })
Write-Host "Skipped: $skipped" -ForegroundColor Yellow
Write-Host ""

if ($failed -eq 0 -and $errors -eq 0) {
    Write-Host "All tests completed successfully!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "Some tests failed. Check output above." -ForegroundColor Red
    exit 1
}

