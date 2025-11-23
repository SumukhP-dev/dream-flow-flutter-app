# Script to check current tables and apply migrations using Supabase CLI
# Usage: .\apply_migrations.ps1

Write-Host "Dream Flow - Supabase Migration Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if linked to a project
Write-Host "Checking if project is linked..." -ForegroundColor Yellow
$linkCheck = npx supabase projects list 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Not linked to a project. You need to link first." -ForegroundColor Red
    Write-Host ""
    Write-Host "To link your project, run:" -ForegroundColor Yellow
    Write-Host "  npx supabase link --project-ref YOUR_PROJECT_REF" -ForegroundColor White
    Write-Host ""
    Write-Host "You can find your project ref in the Supabase Dashboard:" -ForegroundColor Yellow
    Write-Host "  Settings > General > Reference ID" -ForegroundColor White
    exit 1
}

Write-Host "Project is linked. Checking current tables..." -ForegroundColor Green
Write-Host ""

# List current tables in the public schema
Write-Host "Current tables in public schema:" -ForegroundColor Cyan
npx supabase db remote list --schema public

Write-Host ""
Write-Host "Checking migration status..." -ForegroundColor Yellow
npx supabase migration list

Write-Host ""
Write-Host "Applying migrations..." -ForegroundColor Yellow
npx supabase db push

Write-Host ""
Write-Host "Migration complete!" -ForegroundColor Green

