# Quick Render Deployment Script
# Run this to prepare and deploy your backend to Render

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Dream Flow - Render Deployment Helper" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan

# Check if we're in the right directory
if (-not (Test-Path "backend_fastapi")) {
    Write-Host "❌ Error: Must run from project root directory" -ForegroundColor Red
    Write-Host "   Current directory: $(Get-Location)" -ForegroundColor Yellow
    Write-Host "   Expected: Dream_Flow_Flutter_App/" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Found backend_fastapi directory" -ForegroundColor Green

# Check required files
$requiredFiles = @(
    "render.yaml",
    "backend_fastapi/Dockerfile",
    "backend_fastapi/requirements.txt",
    "backend_fastapi/RENDER_DEPLOYMENT_READY.md"
)

foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Host "✅ Found $file" -ForegroundColor Green
    } else {
        Write-Host "❌ Missing $file" -ForegroundColor Red
        exit 1
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Pre-Deployment Checklist" -ForegroundColor Yellow
Write-Host "========================================`n" -ForegroundColor Cyan

# Ask for HuggingFace token
Write-Host "1. Do you have a HuggingFace API token? (y/n): " -NoNewline -ForegroundColor Yellow
$hasHFToken = Read-Host
if ($hasHFToken -ne "y") {
    Write-Host "   Get one at: https://huggingface.co/settings/tokens" -ForegroundColor Cyan
    Write-Host "   You'll need this for Render deployment!" -ForegroundColor Red
}

# Ask for Supabase credentials
Write-Host "`n2. Do you have Supabase credentials? (y/n): " -NoNewline -ForegroundColor Yellow
$hasSupabase = Read-Host
if ($hasSupabase -ne "y") {
    Write-Host "   Get them at: https://supabase.com/dashboard" -ForegroundColor Cyan
    Write-Host "   You'll need: URL, ANON_KEY, SERVICE_ROLE_KEY" -ForegroundColor Red
}

# Check git status
Write-Host "`n3. Checking git status..." -ForegroundColor Yellow
git status --short

Write-Host "`n4. Ready to commit and push? (y/n): " -NoNewline -ForegroundColor Yellow
$readyToPush = Read-Host

if ($readyToPush -eq "y") {
    Write-Host "`n📝 Committing changes..." -ForegroundColor Cyan
    git add render.yaml backend_fastapi/RENDER_DEPLOYMENT_READY.md
    git commit -m "Add Render deployment configuration

- Created render.yaml with complete environment config
- Added deployment readiness guide
- Configured for cloud_only mode (free tier compatible)
- Documented all required environment variables"
    
    Write-Host "`n📤 Pushing to GitHub..." -ForegroundColor Cyan
    git push origin main
    
    Write-Host "`n✅ Changes pushed successfully!" -ForegroundColor Green
} else {
    Write-Host "`n⏸️  Skipping git push. Run manually when ready:" -ForegroundColor Yellow
    Write-Host "   git add render.yaml backend_fastapi/" -ForegroundColor Cyan
    Write-Host "   git commit -m 'Add Render deployment config'" -ForegroundColor Cyan
    Write-Host "   git push origin main" -ForegroundColor Cyan
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Next Steps" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "1. Go to Render Dashboard:" -ForegroundColor Yellow
Write-Host "   https://dashboard.render.com`n" -ForegroundColor Cyan

Write-Host "2. Click 'New +' → 'Blueprint'" -ForegroundColor Yellow

Write-Host "`n3. Connect your GitHub repository" -ForegroundColor Yellow

Write-Host "`n4. Render will detect render.yaml automatically" -ForegroundColor Yellow

Write-Host "`n5. Set Environment Variables in Render:" -ForegroundColor Yellow
Write-Host "   REQUIRED:" -ForegroundColor Red
Write-Host "   - HUGGINGFACE_API_TOKEN" -ForegroundColor Cyan
Write-Host "   - SUPABASE_URL" -ForegroundColor Cyan
Write-Host "   - SUPABASE_ANON_KEY" -ForegroundColor Cyan
Write-Host "   - SUPABASE_SERVICE_ROLE_KEY" -ForegroundColor Cyan

Write-Host "`n6. Click 'Apply' to deploy!" -ForegroundColor Yellow

Write-Host "`n7. Your app will be live in ~10 minutes at:" -ForegroundColor Yellow
Write-Host "   https://dreamflow-backend.onrender.com" -ForegroundColor Green

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Testing Your Deployment" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Once deployed, test with:" -ForegroundColor Yellow
Write-Host "   curl https://your-app.onrender.com/health" -ForegroundColor Cyan
Write-Host "`n   Visit: https://your-app.onrender.com/docs" -ForegroundColor Cyan

Write-Host "`n✅ Deployment preparation complete!" -ForegroundColor Green
Write-Host "📚 Full guide: backend_fastapi/RENDER_DEPLOYMENT_READY.md`n" -ForegroundColor Cyan
