# Setup Environment Variables for Dream Flow Flutter App
# This script creates a .env file with Supabase configuration

Write-Host "🔧 Setting up environment variables..." -ForegroundColor Green

$envContent = @"
# Supabase Configuration
SUPABASE_URL=https://dbpvmfglduprtbpaygmo.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRicHZtZmdsZHVwcnRicGF5Z21vIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzU2MDk2NjksImV4cCI6MjA1MTE4NTY2OX0.w8D2OP3RKjvVAETIdIUqJXOzC3F7-KoIbYrOcwAJH-M

# Backend Configuration (optional - defaults to localhost)
# BACKEND_URL=http://localhost:8080

# Sentry Configuration (optional)
# SENTRY_DSN=your_sentry_dsn_here

# Environment
ENVIRONMENT=development
"@

$envPath = Join-Path $PSScriptRoot ".env"

# Create the .env file
$envContent | Out-File -FilePath $envPath -Encoding UTF8 -NoNewline

Write-Host "✅ Environment file created at: $envPath" -ForegroundColor Green
Write-Host ""
Write-Host "📝 Next steps:" -ForegroundColor Yellow
Write-Host "  1. Hot reload your Flutter app (press 'r' in the terminal)" -ForegroundColor Cyan
Write-Host "  2. If that doesn't work, restart the app (press 'R' for full restart)" -ForegroundColor Cyan
Write-Host ""
Write-Host "The app should now be able to connect to Supabase! 🚀" -ForegroundColor Green
