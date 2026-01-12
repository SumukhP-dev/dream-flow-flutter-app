# PowerShell script to forcefully clean locked build directories
# This script handles Windows file locking issues, especially with OneDrive

param(
    [string]$BuildDir = "build"
)

$ErrorActionPreference = "Continue"

Write-Host "Cleaning build directory: $BuildDir" -ForegroundColor Yellow

# Function to remove directory with retries
function Remove-DirectoryWithRetry {
    param(
        [string]$Path,
        [int]$MaxRetries = 5,
        [int]$DelaySeconds = 2
    )
    
    if (-not (Test-Path $Path)) {
        Write-Host "Path does not exist: $Path" -ForegroundColor Gray
        return $true
    }
    
    for ($i = 1; $i -le $MaxRetries; $i++) {
        try {
            Write-Host "Attempt ${i}/${MaxRetries}: Removing $Path" -ForegroundColor Cyan
            
            # Try to remove read-only attributes first
            Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue | 
                ForEach-Object { 
                    if ($_.Attributes -match "ReadOnly") {
                        $_.Attributes = $_.Attributes -band (-bnot [System.IO.FileAttributes]::ReadOnly)
                    }
                }
            
            # Remove the directory
            Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
            Write-Host "Successfully removed: $Path" -ForegroundColor Green
            return $true
        }
        catch {
                Write-Host "Attempt ${i} failed: $($_.Exception.Message)" -ForegroundColor Yellow
            
            if ($i -lt $MaxRetries) {
                Write-Host "Waiting $DelaySeconds seconds before retry..." -ForegroundColor Gray
                Start-Sleep -Seconds $DelaySeconds
            }
            else {
                Write-Host "Failed to remove after $MaxRetries attempts: $Path" -ForegroundColor Red
                Write-Host "This directory may be locked by:" -ForegroundColor Yellow
                Write-Host "  - OneDrive syncing (try pausing OneDrive)" -ForegroundColor Yellow
                Write-Host "  - File Explorer window open in that directory" -ForegroundColor Yellow
                Write-Host "  - Antivirus scanning" -ForegroundColor Yellow
                Write-Host "  - Another process with files open" -ForegroundColor Yellow
                return $false
            }
        }
    }
    return $false
}

# Get the full path
$FullBuildPath = Resolve-Path -Path $BuildDir -ErrorAction SilentlyContinue
if (-not $FullBuildPath) {
    $FullBuildPath = Join-Path (Get-Location) $BuildDir
}

Write-Host "Full build path: $FullBuildPath" -ForegroundColor Cyan

# Check if the problematic directory exists
$ProblematicDir = Join-Path $FullBuildPath "app\intermediates\packaged_res\debug\packageDebugResources"
if (Test-Path $ProblematicDir) {
    Write-Host "`nFound problematic directory: $ProblematicDir" -ForegroundColor Yellow
    Write-Host "Attempting to remove it first..." -ForegroundColor Cyan
    
    $success = Remove-DirectoryWithRetry -Path $ProblematicDir -MaxRetries 3 -DelaySeconds 3
    
    if (-not $success) {
        Write-Host "`nTrying alternative approach: Removing parent directory..." -ForegroundColor Yellow
        $ParentDir = Split-Path $ProblematicDir -Parent
        Remove-DirectoryWithRetry -Path $ParentDir -MaxRetries 2 -DelaySeconds 2 | Out-Null
    }
}

# Try to clean the entire build directory
Write-Host "`nCleaning entire build directory..." -ForegroundColor Cyan
$success = Remove-DirectoryWithRetry -Path $FullBuildPath -MaxRetries 3 -DelaySeconds 3

if ($success) {
    Write-Host "`nBuild directory cleaned successfully!" -ForegroundColor Green
    Write-Host "You can now run: flutter run" -ForegroundColor Green
}
else {
    Write-Host "`nManual intervention may be required:" -ForegroundColor Red
    Write-Host "1. Pause OneDrive syncing temporarily" -ForegroundColor Yellow
    Write-Host "2. Close any File Explorer windows in the build directory" -ForegroundColor Yellow
    Write-Host "3. Close Android Studio, VS Code, or other IDEs that might have files open" -ForegroundColor Yellow
    Write-Host "4. Try running this script again" -ForegroundColor Yellow
    Write-Host "`nOr manually delete: $FullBuildPath" -ForegroundColor Yellow
    exit 1
}

exit 0

