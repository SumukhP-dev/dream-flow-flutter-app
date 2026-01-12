# Integration Tests for AI Inference Modes

This directory contains comprehensive integration tests for the Dream Flow backend's AI inference system, testing both cloud (HuggingFace) and local (GGUF) inference modes.

## Test Files

### 1. `test_inference_modes_integration.py`
**Full pytest integration test suite**

Tests all three inference modes with proper fixtures and mocking:
- `TestCloudInferenceMode` - Tests HuggingFace cloud APIs
- `TestLocalInferenceMode` - Tests local GGUF models
- `TestFallbackBehavior` - Tests graceful fallback between modes
- `TestInferenceModeConfiguration` - Tests configuration parsing

### 2. `test_inference_e2e.py`
**Standalone end-to-end test script**

Can be run directly without pytest for quick validation:
```bash
python tests/test_inference_e2e.py
```

## Prerequisites

### For Cloud Tests (HuggingFace)
```bash
export HUGGINGFACE_API_TOKEN=hf_your_token_here
```

### For Local Tests (GGUF Models)
```bash
# Download model (if not already present)
cd backend_fastapi
mkdir -p models
cd models
wget https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf

# Install dependencies
pip install llama-cpp-python edge-tts aiofiles torch diffusers
```

## Running Tests

### Option 1: Run All Integration Tests
```bash
cd backend_fastapi
pytest tests/test_inference_modes_integration.py -v -s
```

### Option 2: Run Specific Test Classes
```bash
# Test only cloud mode
pytest tests/test_inference_modes_integration.py::TestCloudInferenceMode -v

# Test only local mode
pytest tests/test_inference_modes_integration.py::TestLocalInferenceMode -v

# Test only fallback behavior
pytest tests/test_inference_modes_integration.py::TestFallbackBehavior -v
```

### Option 3: Run Specific Tests by Keyword
```bash
# Test cloud inference
pytest tests/test_inference_modes_integration.py -k cloud -v

# Test local inference
pytest tests/test_inference_modes_integration.py -k local -v

# Test fallback
pytest tests/test_inference_modes_integration.py -k fallback -v
```

### Option 4: Run Standalone E2E Script
```bash
# Quick validation without pytest
python tests/test_inference_e2e.py
```

### Option 5: Run with Different Inference Modes
```bash
# Cloud only
AI_INFERENCE_MODE=cloud_only pytest tests/test_inference_modes_integration.py -v

# Local only
AI_INFERENCE_MODE=server_only pytest tests/test_inference_modes_integration.py -v

# Cloud with local fallback
AI_INFERENCE_MODE=cloud_first pytest tests/test_inference_modes_integration.py -v
```

## Test Coverage

### Story Generation Tests
- ✅ Cloud story generation (HuggingFace)
- ✅ Local story generation (GGUF/llama.cpp)
- ✅ Story quality validation
- ✅ Timeout handling

### Narration Tests
- ✅ Cloud narration (HuggingFace TTS)
- ✅ Local narration (edge-tts)
- ✅ Audio file generation
- ✅ Multiple voice support

### Visual/Image Tests
- ✅ Cloud image generation (HuggingFace)
- ✅ Local image generation (Stable Diffusion)
- ✅ Multiple scene generation
- ✅ Placeholder fallback

### Pipeline Tests
- ✅ Complete story pipeline (story + audio + images)
- ✅ Parallel generation (audio + images)
- ✅ End-to-end validation

### Fallback Tests
- ✅ Cloud → Local fallback
- ✅ Runtime fallback during generation
- ✅ Fallback disabled in `*_only` modes
- ✅ Fallback chain configuration

## Expected Output

### Successful Cloud Test
```
✅ PASS test_cloud_story_generation (5.23s)
     Story: 287 chars
     Preview: Once upon a time, by the peaceful ocean...
```

### Successful Local Test
```
✅ PASS test_local_story_generation (42.18s)
     Story: 156 chars
     Preview: A friendly turtle named Shelly lived...
```

### Successful Fallback Test
```
✅ PASS test_cloud_to_local_fallback_story (43.52s)
     Fallback: Cloud → Local
     Generator: LocalStoryGenerator
```

## Skipped Tests

Tests will be automatically skipped if:

1. **Cloud tests**: `HUGGINGFACE_API_TOKEN` not set
2. **Local tests**: Model files not present
3. **Image tests**: PyTorch not installed

Example:
```
SKIPPED [1] test_inference_modes_integration.py:180: Local model not available
```

## Performance Benchmarks

Typical execution times:

| Test | Cloud Mode | Local Mode |
|------|-----------|------------|
| Story Generation | 3-7s | 20-60s |
| Narration | 5-10s | 3-8s |
| Images (2 frames) | 10-20s | 60-120s |
| Complete Pipeline | 15-30s | 90-180s |

## Debugging Failed Tests

### View Detailed Output
```bash
pytest tests/test_inference_modes_integration.py -v -s --log-cli-level=DEBUG
```

### Run Single Test
```bash
pytest tests/test_inference_modes_integration.py::TestCloudInferenceMode::test_cloud_story_generation -v -s
```

### Check Environment
```bash
# Verify configuration
python -c "from app.shared.config import get_settings; s = get_settings(); print(f'Mode: {s.ai_inference_mode}'); print(f'Local: {s.local_inference}')"
```

## Common Issues

### Issue: "ModuleNotFoundError: No module named 'llama_cpp'"
**Solution**: Install local inference dependencies
```bash
pip install llama-cpp-python
```

### Issue: "Local model not available"
**Solution**: Download the model
```bash
cd backend_fastapi/models
wget https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf
```

### Issue: "HUGGINGFACE_API_TOKEN is required"
**Solution**: Set your HuggingFace token
```bash
export HUGGINGFACE_API_TOKEN=hf_your_token_here
```

### Issue: "Out of memory" during local tests
**Solution**: Use Q2 model or reduce context
```bash
export LOW_MEMORY_MODE=true
export LOCAL_STORY_MODEL=tinyllama
```

## CI/CD Integration

### GitHub Actions Example
```yaml
name: Integration Tests

on: [push, pull_request]

jobs:
  test-cloud:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      - run: pip install -r requirements.txt
      - run: pytest tests/test_inference_modes_integration.py -k cloud -v
        env:
          HUGGINGFACE_API_TOKEN: ${{ secrets.HUGGINGFACE_API_TOKEN }}
          AI_INFERENCE_MODE: cloud_only

  test-local:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      - run: pip install -r requirements.txt
      - run: pip install llama-cpp-python edge-tts
      - run: |
          mkdir -p backend_fastapi/models
          cd backend_fastapi/models
          wget https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf
      - run: pytest tests/test_inference_modes_integration.py -k local -v
        env:
          AI_INFERENCE_MODE: server_only
```

## Contributing

When adding new tests:

1. Follow the existing test structure
2. Add proper docstrings
3. Use descriptive test names
4. Mock external dependencies (Supabase, file I/O)
5. Test both success and failure cases
6. Add skip conditions for missing dependencies

## Resources

- [Pytest Documentation](https://docs.pytest.org/)
- [HuggingFace Inference API](https://huggingface.co/docs/api-inference)
- [llama.cpp Python Bindings](https://github.com/abetlen/llama-cpp-python)
- [Dream Flow AI Inference Modes](../AI_INFERENCE_MODES.md)
- [Fallback System Documentation](../FALLBACK_SYSTEM_AUDIT_AND_FIXES.md)
