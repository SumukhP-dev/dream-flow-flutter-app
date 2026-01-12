# AI Inference Fallback - Quick Reference

## TL;DR

The backend now has **graceful fallback** from Cloud HuggingFace → Server Local Models → Native Mobile AI chips.

## What Was Fixed

✅ Missing configuration properties added (`use_local_models`, `ollama_*`)  
✅ Fallback order now matches documentation  
✅ Runtime fallback respects `AI_INFERENCE_MODE` configuration  
✅ Visual generation has proper fallback chain  
✅ Comprehensive logging for debugging  

## Quick Start

### Recommended Production Setup
```env
AI_INFERENCE_MODE=cloud_first
HUGGINGFACE_API_TOKEN=hf_xxxxx
LOCAL_INFERENCE=true  # Fallback
```

### Development Setup
```env
AI_INFERENCE_MODE=server_first
LOCAL_INFERENCE=true
HUGGINGFACE_API_TOKEN=hf_xxxxx  # Optional fallback
```

## Available Modes

| Mode | Fallback? | Order |
|------|-----------|-------|
| `cloud_first` | ✅ | Cloud → Local → Mobile |
| `server_first` | ✅ | Local → Cloud → Mobile |
| `phone_first` | ✅ | Mobile → Local → Cloud |
| `cloud_only` | ❌ | Cloud (no fallback) |
| `server_only` | ❌ | Local (no fallback) |
| `phone_only` | ❌ | Mobile (no fallback) |

## Testing Fallback

### Test 1: Cloud to Local
```bash
# Set invalid token to force fallback
AI_INFERENCE_MODE=cloud_first
HUGGINGFACE_API_TOKEN=invalid
LOCAL_INFERENCE=true

# Check logs for:
# "❌ Failed to initialize cloud generators"
# "🔄 Falling back to next option in chain"
# "💻 Using LOCAL inference mode"
```

### Test 2: Local to Cloud
```bash
# Don't install llama-cpp-python
AI_INFERENCE_MODE=server_first
HUGGINGFACE_API_TOKEN=hf_xxxxx

# Check logs for:
# "❌ Failed to initialize local generators"
# "🔄 Falling back to next option in chain"
# "🌐 Using CLOUD inference mode"
```

## Common Issues

### "AttributeError: 'Settings' object has no attribute 'use_local_models'"
**Fixed!** This was a bug in the old code. Update to latest version.

### "All inference options failed"
**Solution**: Ensure at least one mode is properly configured:
- Cloud: Valid `HUGGINGFACE_API_TOKEN`
- Local: `LOCAL_INFERENCE=true` + model files exist
- Mobile: Flutter ML server running on port 8081

### Fallback not working
**Check**:
1. Using fallback mode? (`*_first`, not `*_only`)
2. Fallback option is configured?
3. Check logs for "Fallback disabled" messages

## Logs to Watch

```
# Initialization
🌐 Using CLOUD inference mode (HuggingFace APIs)
💻 Using LOCAL inference mode (CPU-optimized)
📱 Using native mobile inference mode (TFLite/Core ML)

# Fallback
❌ Failed to initialize cloud generators: [error]
🔄 Falling back to next option in chain...
✅ Generators initialized successfully

# Runtime fallback
Primary story generator failed: TimeoutError
Attempting fallback to local story generator
✅ Using fallback story generator
```

## Files Modified

- `app/shared/config.py` - Added Ollama config
- `app/dreamflow/main.py` - Refactored fallback logic
- `AI_INFERENCE_MODES.md` - Updated documentation
- `FALLBACK_SYSTEM_AUDIT_AND_FIXES.md` - Detailed audit report
- `docs/FALLBACK_FLOW_DIAGRAM.md` - Visual flow diagrams

## Next Steps

1. Test in staging with real workloads
2. Monitor fallback frequency (high rate = config issue)
3. Adjust fallback chains based on performance data
4. Consider circuit breaker for repeated failures

## Questions?

See full documentation:
- `FALLBACK_SYSTEM_AUDIT_AND_FIXES.md` - Complete audit report
- `docs/FALLBACK_FLOW_DIAGRAM.md` - Visual flow diagrams
- `AI_INFERENCE_MODES.md` - Configuration guide

---

**Last Updated**: January 11, 2026  
**Status**: ✅ Ready for testing
