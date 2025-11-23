# PowerShell script to generate Flutter localization files
# Run this from the project root directory

Write-Host "Generating Flutter localization files..." -ForegroundColor Blue

# Navigate to Flutter directory
Set-Location frontend_flutter

# Ensure generated directory exists
if (-not (Test-Path lib/generated)) {
    New-Item -ItemType Directory -Path lib/generated -Force | Out-Null
}

# Run Flutter localization generation
Write-Host "Running: flutter gen-l10n" -ForegroundColor Yellow
flutter gen-l10n

if ($LASTEXITCODE -eq 0) {
    Write-Host "Localization files generated successfully!" -ForegroundColor Green
    Write-Host "Generated files are in: lib/generated/" -ForegroundColor Green
} else {
    Write-Host "Error generating localization files." -ForegroundColor Red
    Write-Host "If you see permission errors, try:" -ForegroundColor Yellow
    Write-Host "  1. Close any programs accessing the lib/l10n directory" -ForegroundColor Yellow
    Write-Host "  2. Check OneDrive sync status" -ForegroundColor Yellow
    Write-Host "  3. Run as administrator if needed" -ForegroundColor Yellow
}

# Return to project root
Set-Location ..

