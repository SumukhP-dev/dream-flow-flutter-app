# Quick test runner for AI inference integration tests (PowerShell)
#
# Usage:
#   .\run_inference_tests.ps1           # Run all tests
#   .\run_inference_tests.ps1 cloud     # Test cloud only
#   .\run_inference_tests.ps1 local     # Test local only
#   .\run_inference_tests.ps1 fallback  # Test fallback only
#   .\run_inference_tests.ps1 e2e       # Run standalone E2E script

param(
    [string]$TestType = "all"
)

# Colors (limited in PowerShell)
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

Write-ColorOutput Blue "======================================"
Write-ColorOutput Blue "AI Inference Integration Tests"
Write-ColorOutput Blue "======================================`n"

# Get paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BackendDir = Split-Path -Parent $ScriptDir

# Check for HuggingFace token
if (-not $env:HUGGINGFACE_API_TOKEN) {
    Write-ColorOutput Yellow "⚠️  HUGGINGFACE_API_TOKEN not set. Cloud tests will be skipped."
    Write-ColorOutput Yellow "   Set with: `$env:HUGGINGFACE_API_TOKEN='hf_your_token'`n"
}

# Check for local model
$ModelPath = Join-Path $BackendDir "models\tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"
if (-not (Test-Path $ModelPath)) {
    Write-ColorOutput Yellow "⚠️  Local model not found at $ModelPath"
    Write-ColorOutput Yellow "   Local tests will be skipped.`n"
}

# Change to backend directory
Set-Location $BackendDir

# Check for pytest
try {
    Get-Command pytest -ErrorAction Stop | Out-Null
} catch {
    Write-ColorOutput Red "❌ pytest not found. Install with: pip install pytest pytest-asyncio"
    exit 1
}

# Run tests based on argument
switch ($TestType) {
    "cloud" {
        Write-ColorOutput Green "Running cloud inference tests...`n"
        $env:AI_INFERENCE_MODE = "cloud_only"
        pytest tests/test_inference_modes_integration.py::TestCloudInferenceMode -v -s
    }
    
    "local" {
        Write-ColorOutput Green "Running local inference tests...`n"
        $env:AI_INFERENCE_MODE = "server_only"
        pytest tests/test_inference_modes_integration.py::TestLocalInferenceMode -v -s
    }
    
    "fallback" {
        Write-ColorOutput Green "Running fallback tests...`n"
        $env:AI_INFERENCE_MODE = "cloud_first"
        pytest tests/test_inference_modes_integration.py::TestFallbackBehavior -v -s
    }
    
    "e2e" {
        Write-ColorOutput Green "Running standalone E2E tests...`n"
        python tests/test_inference_e2e.py
    }
    
    default {
        Write-ColorOutput Green "Running all integration tests...`n"
        pytest tests/test_inference_modes_integration.py -v -s
    }
}

# Check exit code
if ($LASTEXITCODE -eq 0) {
    Write-ColorOutput Green "`n✅ Tests completed successfully!"
} else {
    Write-ColorOutput Red "`n❌ Some tests failed. Check output above for details."
    exit 1
}
