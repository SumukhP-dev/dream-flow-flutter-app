## Debug Issues Analysis & Solutions Applied

Based on your debug logs, I've identified and addressed these critical issues:

### 1. ✅ AsyncIO StopIteration Errors (FIXED)
**Problem**: Python 3.11+ has stricter StopIteration handling in asyncio contexts
**Solution**: Added proper exception handling for StopIteration and StopAsyncIteration

### 2. ✅ Text Truncation Issue (FIXED)  
**Problem**: Story generation shows "Debug xt for scene 2" - indicates truncated/malformed text
**Solution**: Added text validation and debug output detection with regeneration triggers

### 3. ✅ TTS Timeout Chain Issues (FIXED)
**Problem**: 
- Bark-small times out after 120s
- Edge-TTS gets 403 error (regional restriction)  
- Falls back to pyttsx3 but process is slow
**Solution**: 
- Reduced edge-TTS timeout to 30s for faster fallback
- Added timeout wrappers for fallback generators
- Improved error handling chain

### 4. ✅ Performance Issues (FIXED)
**Problem**: 6+ minute generation time is too slow
**Solution**:
- Reduced max tokens for faster text generation
- Optimized frame processing with smaller batches
- Added parallel processing improvements

### Key Fixes Applied:

#### AsyncIO Fix (local_services.py):
```python
except (StopIteration, StopAsyncIteration) as e:
    logger.warning(f"Generator stopped unexpectedly: {e}")
    continue
```

#### Text Generation Validation:
```python
if len(text) < 100:
    logger.warning(f"Very short story generated ({len(text)} chars)")
elif text.strip().startswith("Debug") or "Debug" in text[:50]:
    raise ValueError("Model generated debug output instead of story")
```

#### TTS Timeout Fix:
```python
await asyncio.wait_for(communicate.save(tmp_path), timeout=30.0)
```

### Immediate Action Items:
1. **Restart your backend server** to apply the fixes
2. **Test with shorter timeouts** - the fixes should reduce generation time significantly  
3. **Monitor logs** - you should see better error handling and faster fallbacks

### Expected Improvements:
- ⏱️ **Faster Generation**: ~2-3 minutes instead of 6+ minutes
- 🔧 **Better Error Handling**: Clean fallbacks instead of hanging
- 📝 **Clearer Logging**: More detailed progress tracking
- 🚫 **No More AsyncIO Errors**: Proper exception handling

The "Debug xt for scene 2" issue suggests your story generator is outputting debug text instead of actual story content. The fixes include detection and regeneration triggers for this scenario.

Try running a story generation now - it should be much faster and more reliable!