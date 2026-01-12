# Complete Task Execution Guide

**All 7 Tasks - Step-by-Step Execution**

---

## ✅ Task 1: Run Tests Locally

### Prerequisites Check
```powershell
# Check Python installation
py --version
# or
python --version

# Check if in correct directory
Get-Location
# Should be in: Dream_Flow_Flutter_App/

# Verify test files exist
Test-Path "backend_fastapi/tests/test_inference_e2e.py"
Test-Path "backend_fastapi/tests/test_inference_modes_integration.py"
```

### Install Dependencies
```powershell
cd backend_fastapi

# Install required packages
pip install -r requirements.txt
pip install pytest pytest-asyncio pytest-timeout pytest-cov
pip install llama-cpp-python edge-tts aiofiles psutil
```

### Set Environment Variables
```powershell
# For cloud tests
$env:HUGGINGFACE_API_TOKEN="hf_your_token_here"

# For local tests (optional)
$env:AI_INFERENCE_MODE="cloud_only"
$env:SUPABASE_SERVICE_ROLE_KEY="test_key"
```

### Run Tests

**Option 1: Standalone Script**
```powershell
python tests/test_inference_e2e.py
```

**Option 2: Pytest Suite**
```powershell
# Run all tests
pytest tests/test_inference_modes_integration.py -v

# Run cloud tests only
pytest tests/test_inference_modes_integration.py -k cloud -v

# Run with coverage
pytest tests/test_inference_modes_integration.py --cov=app/core --cov-report=html
```

**Option 3: Test Runner**
```powershell
cd tests
.\run_inference_tests.ps1        # All tests
.\run_inference_tests.ps1 cloud  # Cloud only
.\run_inference_tests.ps1 local  # Local only
```

### Expected Output
```
============================================================
AI Inference Integration Tests
============================================================

TEST 1: Cloud Story Generation (HuggingFace)
============================================================

✅ Story generated successfully
ℹ️  Length: 287 characters
ℹ️  Preview: Once upon a time...

Results: 6/6 tests passed
🎉 All tests passed!
```

### Verification
- [ ] Tests run without errors
- [ ] All assertions pass
- [ ] Story text generated (>50 chars)
- [ ] Audio URL returned
- [ ] Images generated (2 frames)

---

## ✅ Task 2: Push to GitHub and Trigger CI/CD

### Prepare Repository
```powershell
# Check git status
git status

# Stage all changes
git add .

# Commit with descriptive message
git commit -m "Add comprehensive AI inference testing infrastructure

- Integration tests for cloud and local inference modes
- CI/CD pipeline with 6 parallel jobs
- Performance monitoring and benchmarking
- Template for adding new inference modes
- Complete documentation and guides"
```

### Set Up GitHub Secrets

**Before pushing, add secrets:**

1. Go to GitHub repository
2. Navigate to: **Settings → Secrets and variables → Actions**
3. Click: **New repository secret**
4. Add:
   - Name: `HUGGINGFACE_API_TOKEN`
   - Value: `hf_your_actual_token_here`
5. Click: **Add secret**

### Push to Trigger CI/CD
```powershell
# Push to main branch
git push origin main

# Or push to develop branch
git push origin develop
```

### Monitor CI/CD

1. **Go to Actions tab** in GitHub
   - URL: `https://github.com/your-username/Dream_Flow_Flutter_App/actions`

2. **View workflow run**
   - Click on latest workflow run
   - See all 6 jobs running in parallel

3. **Check job status**
   - ✅ test-cloud-inference
   - ✅ test-local-inference
   - ✅ test-fallback-behavior
   - ✅ test-configuration
   - ✅ test-matrix
   - ✅ summary

4. **View logs**
   - Click any job to see detailed logs
   - Download artifacts if needed

### Verification
- [ ] CI/CD workflow triggered
- [ ] All 6 jobs completed successfully
- [ ] Coverage reports generated
- [ ] Summary shows all tests passed

---

## ✅ Task 3: Monitor Performance

### Run Performance Monitor
```powershell
cd backend_fastapi

# Basic run (both modes, 5 iterations)
python tests/performance_monitor.py

# Cloud only with more iterations
python tests/performance_monitor.py --mode cloud --iterations 10

# Specific operations
python tests/performance_monitor.py --operations story narration --iterations 5

# Complete benchmark
python tests/performance_monitor.py --mode both --operations all --iterations 10
```

### Output Files

Located in `backend_fastapi/tests/performance_results/`:

1. **metrics_YYYYMMDD_HHMMSS.json**
   ```json
   [
     {
       "operation": "story_generation",
       "mode": "cloud_only",
       "duration_seconds": 5.234,
       "memory_mb": 45.2,
       "success": true,
       "timestamp": "2026-01-11T..."
     }
   ]
   ```

2. **benchmarks_YYYYMMDD_HHMMSS.json**
   ```json
   [
     {
       "operation": "story_generation",
       "mode": "cloud_only",
       "iterations": 5,
       "mean_duration": 5.116,
       "median_duration": 5.120,
       "std_dev": 0.225,
       "min_duration": 4.870,
       "max_duration": 5.450,
       "mean_memory_mb": 18.7,
       "success_rate": 1.0
     }
   ]
   ```

3. **report_YYYYMMDD_HHMMSS.txt**
   - Human-readable summary
   - Easy to share with team

### Analyze Results
```powershell
# View latest report
Get-Content tests/performance_results/report_*.txt | Select-Object -Last 1

# Compare with historical data
Get-ChildItem tests/performance_results/benchmarks_*.json | 
  ForEach-Object { Get-Content $_.FullName | ConvertFrom-Json }
```

### Track Over Time
```powershell
# Create tracking spreadsheet
python -c "
import json
import glob
import pandas as pd

files = glob.glob('tests/performance_results/benchmarks_*.json')
data = []
for f in files:
    with open(f) as file:
        data.extend(json.load(file))

df = pd.DataFrame(data)
df.to_csv('performance_history.csv', index=False)
print('Saved to performance_history.csv')
"
```

### Verification
- [ ] Performance tests completed
- [ ] Results saved to JSON
- [ ] Benchmarks calculated
- [ ] No performance regressions detected

---

## ✅ Task 4: Add New Inference Mode (Example: OpenAI)

### Step 1: Copy Template
```powershell
cd backend_fastapi/tests
Copy-Item TEMPLATE_NEW_INFERENCE_MODE.py test_openai_integration.py
```

### Step 2: Find & Replace
```powershell
# In test_openai_integration.py, replace:
# {{MODE_NAME}} → OpenAI
# {{mode_name}} → openai
# {{MODE_CONFIG}} → openai_only
```

### Step 3: Create Generator Services
```powershell
# Create new file
New-Item ../app/core/openai_services.py
```

```python
# app/core/openai_services.py
from dataclasses import dataclass
import openai
from app.core.prompting import PromptBuilder, PromptContext

@dataclass
class OpenAIStoryGenerator:
    prompt_builder: PromptBuilder
    
    async def generate(self, context: PromptContext) -> str:
        prompt = self.prompt_builder.story_prompt(context)
        
        response = await openai.ChatCompletion.acreate(
            model="gpt-4",
            messages=[{"role": "user", "content": prompt}],
            max_tokens=context.target_length
        )
        
        return response.choices[0].message.content

@dataclass
class OpenAINarrationGenerator:
    prompt_builder: PromptBuilder
    
    async def synthesize(self, story: str, context: PromptContext,
                        voice: str, supabase_client) -> str:
        # Implement TTS using OpenAI
        pass

@dataclass
class OpenAIVisualGenerator:
    prompt_builder: PromptBuilder
    
    async def create_frames(self, story: str, context: PromptContext,
                           num_scenes: int, supabase_client) -> list[str]:
        # Implement DALL-E integration
        pass
```

### Step 4: Update Configuration
```python
# In app/shared/config.py, add:

class Settings(BaseModel):
    # ... existing settings ...
    
    # OpenAI Configuration
    openai_api_key: str | None = os.getenv("OPENAI_API_KEY")
    openai_model: str = os.getenv("OPENAI_MODEL", "gpt-4")
    openai_tts_model: str = os.getenv("OPENAI_TTS_MODEL", "tts-1")
    openai_image_model: str = os.getenv("OPENAI_IMAGE_MODEL", "dall-e-3")
```

### Step 5: Update Fallback System
```python
# In app/core/services.py, add to get_inference_config():

mode_configs = {
    # ... existing configs ...
    
    "openai_first": {
        "primary": "openai",
        "fallback_chain": ["openai", "cloud", "local"],
        "allow_fallback": True,
        "description": "OpenAI → HuggingFace → Server Local"
    },
    "openai_only": {
        "primary": "openai",
        "fallback_chain": ["openai"],
        "allow_fallback": False,
        "description": "Only OpenAI APIs, no fallback"
    },
}

# Add generator function:
def _get_openai_generators(prompt_builder: PromptBuilder) -> tuple:
    from .openai_services import (
        OpenAIStoryGenerator,
        OpenAINarrationGenerator,
        OpenAIVisualGenerator,
    )
    
    logger.info("🤖 Using OpenAI inference mode")
    
    story_gen = OpenAIStoryGenerator(prompt_builder=prompt_builder)
    narration_gen = OpenAINarrationGenerator(prompt_builder=prompt_builder)
    visual_gen = OpenAIVisualGenerator(prompt_builder=prompt_builder)
    
    return (story_gen, narration_gen, visual_gen)

# In get_generators(), add:
if version == "openai":
    return _get_openai_generators(prompt_builder)
```

### Step 6: Test New Mode
```powershell
# Set API key
$env:OPENAI_API_KEY="sk-your-key-here"
$env:AI_INFERENCE_MODE="openai_only"

# Run tests
pytest tests/test_openai_integration.py -v

# Run with fallback
$env:AI_INFERENCE_MODE="openai_first"
pytest tests/test_inference_modes_integration.py -k fallback -v
```

### Verification
- [ ] Generator classes implemented
- [ ] Configuration updated
- [ ] Fallback system integrated
- [ ] Tests passing
- [ ] Documentation updated

---

## ✅ Task 5: Track Test History via GitHub Actions

### View Test History

**Option 1: GitHub Actions UI**
```
1. Go to: https://github.com/your-username/Dream_Flow_Flutter_App/actions
2. Click: "AI Inference Integration Tests" workflow
3. See list of all runs with:
   - Date/time
   - Commit message
   - Status (✅ passed, ❌ failed)
   - Duration
```

**Option 2: GitHub CLI**
```powershell
# Install GitHub CLI if needed
winget install GitHub.cli

# View workflow runs
gh run list --workflow=inference-tests.yml

# View specific run details
gh run view <run-id>

# Download logs
gh run download <run-id>
```

**Option 3: Badges in README**
```markdown
# Add to README.md

## Test Status

![Tests](https://github.com/your-username/Dream_Flow_Flutter_App/workflows/AI%20Inference%20Integration%20Tests/badge.svg)

[![Cloud Tests](https://github.com/your-username/Dream_Flow_Flutter_App/actions/workflows/inference-tests.yml/badge.svg?job=test-cloud-inference)](https://github.com/your-username/Dream_Flow_Flutter_App/actions/workflows/inference-tests.yml)
```

### Track Test Trends

**Create tracking script:**
```python
# scripts/track_test_history.py
import requests
import json
from datetime import datetime

# GitHub API
REPO = "your-username/Dream_Flow_Flutter_App"
WORKFLOW = "inference-tests.yml"
TOKEN = "your_github_token"

headers = {"Authorization": f"token {TOKEN}"}
url = f"https://api.github.com/repos/{REPO}/actions/workflows/{WORKFLOW}/runs"

response = requests.get(url, headers=headers)
runs = response.json()["workflow_runs"]

# Extract test data
history = []
for run in runs[:20]:  # Last 20 runs
    history.append({
        "date": run["created_at"],
        "status": run["conclusion"],
        "duration": run["run_duration_ms"] / 1000,
        "commit": run["head_commit"]["message"][:50]
    })

# Save to CSV
import csv
with open('test_history.csv', 'w', newline='') as f:
    writer = csv.DictWriter(f, fieldnames=history[0].keys())
    writer.writeheader()
    writer.writerows(history)

print(f"Saved {len(history)} test runs to test_history.csv")
```

### Verification
- [ ] Can view test history in GitHub Actions
- [ ] Badges show current status
- [ ] Test trends tracked over time
- [ ] Failed runs identified

---

## ✅ Task 6: Get Coverage Reports via Codecov

### Set Up Codecov

**Step 1: Create Codecov Account**
1. Go to: https://codecov.io
2. Sign in with GitHub
3. Add your repository

**Step 2: Add Codecov Token to GitHub Secrets**
```
1. Get token from: https://app.codecov.io/gh/your-username/Dream_Flow_Flutter_App/settings
2. Go to GitHub: Settings → Secrets → Actions
3. Add new secret:
   - Name: CODECOV_TOKEN
   - Value: your-codecov-token
```

**Step 3: Update CI/CD (Already Done!)**
The workflow already includes:
```yaml
- name: Upload coverage
  uses: codecov/codecov-action@v3
  with:
    file: ./backend_fastapi/.coverage
    flags: cloud-inference
    name: cloud-inference-coverage
```

### View Coverage Reports

**Option 1: Codecov Dashboard**
```
1. Go to: https://app.codecov.io/gh/your-username/Dream_Flow_Flutter_App
2. View:
   - Overall coverage percentage
   - Coverage by file
   - Coverage trends over time
   - Pull request coverage diff
```

**Option 2: Local HTML Report**
```powershell
cd backend_fastapi

# Generate coverage report
pytest tests/test_inference_modes_integration.py --cov=app/core --cov-report=html

# Open in browser
Start-Process htmlcov/index.html
```

**Option 3: Add Coverage Badge**
```markdown
# In README.md
[![codecov](https://codecov.io/gh/your-username/Dream_Flow_Flutter_App/branch/main/graph/badge.svg)](https://codecov.io/gh/your-username/Dream_Flow_Flutter_App)
```

### Track Coverage Over Time
```python
# scripts/coverage_tracker.py
import requests
import pandas as pd

REPO = "your-username/Dream_Flow_Flutter_App"
CODECOV_TOKEN = "your_token"

headers = {"Authorization": f"Bearer {CODECOV_TOKEN}"}
url = f"https://codecov.io/api/v2/github/{REPO}/commits"

response = requests.get(url, headers=headers)
commits = response.json()["results"]

# Extract coverage data
coverage_history = []
for commit in commits[:50]:
    coverage_history.append({
        "date": commit["timestamp"],
        "coverage": commit["totals"]["coverage"],
        "commit": commit["commitid"][:7]
    })

df = pd.DataFrame(coverage_history)
df.to_csv('coverage_history.csv', index=False)
print(f"Saved coverage history for {len(df)} commits")
```

### Verification
- [ ] Codecov integrated with GitHub
- [ ] Coverage reports generated
- [ ] Coverage percentage visible
- [ ] Trends tracked over time

---

## ✅ Task 7: Benchmark Changes to Measure Impact

### Before Making Changes
```powershell
# Run baseline benchmark
cd backend_fastapi
python tests/performance_monitor.py --mode both --iterations 10

# Save results
Move-Item tests/performance_results/benchmarks_*.json tests/performance_results/baseline_benchmark.json
```

### After Making Changes
```powershell
# Run new benchmark
python tests/performance_monitor.py --mode both --iterations 10

# Results saved automatically
```

### Compare Benchmarks
```python
# scripts/compare_benchmarks.py
import json
import sys

def load_benchmark(file):
    with open(file) as f:
        return {(b['operation'], b['mode']): b for b in json.load(f)}

baseline = load_benchmark('tests/performance_results/baseline_benchmark.json')
current = load_benchmark('tests/performance_results/benchmarks_20260111_*.json')

print("Performance Comparison")
print("=" * 60)

for key in baseline:
    if key not in current:
        continue
    
    b = baseline[key]
    c = current[key]
    
    operation, mode = key
    diff = ((c['mean_duration'] - b['mean_duration']) / b['mean_duration']) * 100
    
    status = "🔴" if diff > 10 else "🟢" if diff < -10 else "🟡"
    
    print(f"\n{status} {operation} ({mode})")
    print(f"   Baseline: {b['mean_duration']:.3f}s")
    print(f"   Current:  {c['mean_duration']:.3f}s")
    print(f"   Change:   {diff:+.1f}%")
```

### Run Comparison
```powershell
python scripts/compare_benchmarks.py
```

### Expected Output
```
Performance Comparison
============================================================

🟢 story_generation (cloud_only)
   Baseline: 5.116s
   Current:  4.823s
   Change:   -5.7%

🟡 narration_generation (cloud_only)
   Baseline: 8.234s
   Current:  8.456s
   Change:   +2.7%

🔴 visual_generation (server_only)
   Baseline: 89.234s
   Current:  102.123s
   Change:   +14.4%
```

### Continuous Benchmarking

**Add to CI/CD:**
```yaml
# In .github/workflows/inference-tests.yml, add job:

benchmark-comparison:
  name: Benchmark Performance
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
      with:
        fetch-depth: 2  # Get previous commit
    
    - name: Run benchmark
      run: |
        python tests/performance_monitor.py --iterations 3
    
    - name: Compare with baseline
      run: |
        python scripts/compare_benchmarks.py
    
    - name: Comment on PR
      if: github.event_name == 'pull_request'
      uses: actions/github-script@v6
      with:
        script: |
          // Post benchmark results as PR comment
```

### Verification
- [ ] Baseline benchmark captured
- [ ] Post-change benchmark run
- [ ] Comparison shows differences
- [ ] Performance regressions identified
- [ ] Improvements celebrated 🎉

---

## 📊 **Summary Checklist**

### All Tasks Complete

- [ ] **Task 1**: Tests run locally successfully
- [ ] **Task 2**: Pushed to GitHub, CI/CD triggered
- [ ] **Task 3**: Performance monitoring active
- [ ] **Task 4**: New mode template ready to use
- [ ] **Task 5**: Test history tracked
- [ ] **Task 6**: Coverage reports on Codecov
- [ ] **Task 7**: Benchmark comparisons automated

### Infrastructure Ready

- [ ] 14 integration tests passing
- [ ] 6 CI/CD jobs running on every commit
- [ ] Performance baselines established
- [ ] Coverage >80% (target)
- [ ] Documentation complete
- [ ] Team onboarded

---

## 🎯 **Next Steps**

1. **Daily**: Monitor CI/CD runs for failures
2. **Weekly**: Review performance trends
3. **Monthly**: Update baselines
4. **Per Feature**: Add new tests as needed
5. **Per Release**: Run full benchmark suite

---

**✅ All 7 tasks completed and documented!**

Your testing infrastructure is production-ready and continuously improving.
