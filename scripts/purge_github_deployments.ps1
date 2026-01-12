# Script to purge GitHub deployment history
# Requires GitHub Personal Access Token with repo scope

param(
    [Parameter(Mandatory=$true)]
    [string]$GitHubToken,
    
    [Parameter(Mandatory=$false)]
    [string]$Owner = "SumukhP-dev",
    
    [Parameter(Mandatory=$false)]
    [string]$Repo = "Dream_Flow_Flutter_App"
)

$baseUrl = "https://api.github.com/repos/$Owner/$Repo"
$headers = @{
    "Authorization" = "token $GitHubToken"
    "Accept" = "application/vnd.github.v3+json"
}

Write-Host "Fetching deployments for $Owner/$Repo..." -ForegroundColor Cyan

# Get all deployments
$deploymentsUrl = "$baseUrl/deployments"
$deployments = @()

try {
    $response = Invoke-RestMethod -Uri $deploymentsUrl -Headers $headers -Method Get
    $deployments = $response
    
    Write-Host "Found $($deployments.Count) deployments" -ForegroundColor Yellow
    
    if ($deployments.Count -eq 0) {
        Write-Host "No deployments found. Nothing to purge." -ForegroundColor Green
        exit 0
    }
    
    # Delete each deployment
    foreach ($deployment in $deployments) {
        $deploymentId = $deployment.id
        $deploymentUrl = "$baseUrl/deployments/$deploymentId"
        
        Write-Host "Deleting deployment $deploymentId (Environment: $($deployment.environment), Ref: $($deployment.ref))..." -ForegroundColor Yellow
        
        try {
            Invoke-RestMethod -Uri $deploymentUrl -Headers $headers -Method Delete
            Write-Host "  ✓ Deleted deployment $deploymentId" -ForegroundColor Green
        } catch {
            Write-Host "  ✗ Failed to delete deployment $deploymentId : $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    Write-Host "`nDeployment purge complete!" -ForegroundColor Green
    
} catch {
    Write-Host "Error fetching deployments: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`nNote: You may need to:" -ForegroundColor Yellow
    Write-Host "1. Create a GitHub Personal Access Token with 'repo' scope" -ForegroundColor Yellow
    Write-Host "2. Run: .\scripts\purge_github_deployments.ps1 -GitHubToken YOUR_TOKEN" -ForegroundColor Yellow
    exit 1
}

# Note about workflow runs
Write-Host "`nNote: GitHub Actions workflow runs cannot be deleted via API." -ForegroundColor Yellow
Write-Host "To delete workflow runs, go to:" -ForegroundColor Yellow
Write-Host "  https://github.com/$Owner/$Repo/actions" -ForegroundColor Cyan
Write-Host "And manually delete runs, or delete the workflow files entirely." -ForegroundColor Yellow

