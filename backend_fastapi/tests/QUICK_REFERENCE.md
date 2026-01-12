# Integration Tests - Quick Reference Card

## 🚀 Fastest Way to Run Tests

```bash
# Option 1: Standalone script (no pytest needed)
cd backend_fastapi
python tests/test_inference_e2e.py

# Option 2: Pytest (more detailed)
pytest tests/test_inference_modes_integration.py -v

# Option 3: Test runner
./tests/run_inference_tests.sh        # Linux/Mac
.\tests\run_inference_tests.ps1       # Windows
```

## 📋 Prerequisites Checklist

- [ ] **For cloud tests**: `export HUGGINGFACE_API_TOKEN=hf_xxxxx`
- [ ] **For local tests**: Download model to `backend_fastapi/models/`
- [ ] **Dependencies**: `pip install pytest pytest-asyncio llama-cpp-python edge-tts`

## 🎯 Test Commands

| What to Test | Command |
|-------------|---------|
| Everything | `pytest tests/test_inference_modes_integration.py -v` |
| Cloud only | `pytest tests/test_inference_modes_integration.py -k cloud -v` |
| Local only | `pytest tests/test_inference_modes_integration.py -k local -v` |
| Fallback | `pytest tests/test_inference_modes_integration.py -k fallback -v` |
| Story only | `pytest tests/test_inference_modes_integration.py -k story -v` |
| Narration only | `pytest tests/test_inference_modes_integration.py -k narration -v` |
| Images only | `pytest tests/test_inference_modes_integration.py -k visual -v` |

## ⚡ What Each Test Does

### Cloud Tests
- ✅ **Story**: Generates text using HuggingFace LLM
- ✅ **Narration**: Creates audio using HuggingFace TTS
- ✅ **Images**: Generates frames using HuggingFace Diffusion
- ✅ **Pipeline**: Runs all three in parallel

### Local Tests
- ✅ **Story**: Generates text using local GGUF model
- ✅ **Narration**: Creates audio using edge-tts
- ✅ **Images**: Generates frames using local Stable Diffusion
- ✅ **Pipeline**: Runs all three in parallel

### Fallback Tests
- ✅ **Cloud→Local**: Tests automatic fallback when cloud fails
- ✅ **Runtime**: Tests fallback during generation
- ✅ **Disabled**: Verifies `*_only` modes don't fallback

## 🐛 Common Errors

| Error | Fix |
|-------|-----|
| `No module named 'llama_cpp'` | `pip install llama-cpp-python` |
| `Local model not available` | Download from HuggingFace (see README) |
| `HUGGINGFACE_API_TOKEN required` | `export HUGGINGFACE_API_TOKEN=hf_xxx` |
| `Out of memory` | Set `LOW_MEMORY_MODE=true` |
| Tests are slow | Run specific subset: `-k cloud` or `-k story` |

## ⏱️ Expected Times

| Test | Cloud | Local |
|------|-------|-------|
| Story | 3-7s | 20-60s |
| Audio | 5-10s | 3-8s |
| Images (2) | 10-20s | 60-120s |
| Full Pipeline | 15-30s | 90-180s |

## 📊 Success Output Example

```
✅ PASS test_cloud_story_generation (5.23s)
   Story: 287 chars
   Preview: Once upon a time...

✅ PASS test_cloud_narration_generation (8.41s)
   Audio: https://test.supabase.co/audio/test.wav

✅ PASS test_cloud_visual_generation (15.67s)
   Frames: 2 images

✅ PASS test_cloud_full_story_pipeline (28.15s)
   Story: 287 chars | Audio: ✓ | Frames: 2
```

## 🔧 Environment Variables

```bash
# Required
export HUGGINGFACE_API_TOKEN=hf_xxxxx
export SUPABASE_SERVICE_ROLE_KEY=your_key

# Optional (for specific tests)
export AI_INFERENCE_MODE=cloud_first  # or server_first, phone_first
export LOCAL_INFERENCE=true
export LOCAL_MODEL_PATH=./models/tinyllama.gguf
export USE_PLACEHOLDERS_ONLY=false
```

## 📁 Files Created

1. `test_inference_modes_integration.py` - Full pytest suite
2. `test_inference_e2e.py` - Standalone script
3. `run_inference_tests.sh` - Bash runner
4. `run_inference_tests.ps1` - PowerShell runner
5. `INTEGRATION_TESTS_README.md` - Full documentation
6. `INTEGRATION_TESTS_SUMMARY.md` - Complete overview

## 🎓 Learn More

- Full docs: `backend_fastapi/tests/INTEGRATION_TESTS_README.md`
- Inference modes: `backend_fastapi/AI_INFERENCE_MODES.md`
- Fallback system: `backend_fastapi/FALLBACK_SYSTEM_AUDIT_AND_FIXES.md`

---
**Quick Help**: `pytest tests/test_inference_modes_integration.py --help`
