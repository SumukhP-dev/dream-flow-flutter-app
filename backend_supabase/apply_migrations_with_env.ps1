# Script to apply migrations using password from .env file
# Usage: .\apply_migrations_with_env.ps1

Write-Host "Dream Flow - Applying Supabase Migrations" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# Check if .env file exists
$envPath = Join-Path $PSScriptRoot ".env"
if (-not (Test-Path $envPath)) {
    Write-Host "Error: .env file not found!" -ForegroundColor Red
    Write-Host "Please create a .env file in backend_supabase with:" -ForegroundColor Yellow
    Write-Host "  SUPABASE_DB_PASSWORD=your_password_here" -ForegroundColor White
    exit 1
}

# Load .env file
Write-Host "Loading .env file..." -ForegroundColor Yellow
Get-Content $envPath | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]*)\s*=\s*(.*)$') {
        $key = $matches[1].Trim()
        $value = $matches[2].Trim()
        [Environment]::SetEnvironmentVariable($key, $value, "Process")
    }
}

$password = $env:SUPABASE_DB_PASSWORD
if (-not $password) {
    Write-Host "Error: SUPABASE_DB_PASSWORD not found in .env file!" -ForegroundColor Red
    exit 1
}

Write-Host "Password loaded from .env" -ForegroundColor Green
Write-Host ""

# Check migration status
Write-Host "Checking migration status..." -ForegroundColor Yellow
npx supabase migration list

Write-Host ""
Write-Host "Applying migrations..." -ForegroundColor Yellow
npx supabase db push --password $password

Write-Host ""
Write-Host "Verifying migrations..." -ForegroundColor Yellow
npx supabase migration list

Write-Host ""
Write-Host "Done!" -ForegroundColor Green

