# Render Free Tier Configuration Guide

## 🎯 Critical Configuration for Free Tier Deployment

This guide explains why and how to configure DreamFlow for Render's free tier (512MB RAM).

---

## ⚠️ The Problem

When deploying to Render's free tier, **story generation can hang or timeout** if not properly configured. This happens because:

### 1. **Memory Constraints**
- Free tier provides only **512MB RAM**
- Stable Diffusion image models require **2GB+ RAM**
- Attempting to load these models causes:
  - Out of memory errors
  - 30-second timeouts
  - Backend becoming unresponsive

### 2. **Configuration Mismatch**
If `USE_PLACEHOLDERS_ONLY` is set to `false`:
- Backend tries to download image models (several GB)
- Attempts to load them into 512MB RAM (impossible)
- Hits timeout, but wastes 30+ seconds
- Falls back to placeholders anyway (after delay)

### 3. **Frontend Hanging**
When the backend is slow or unresponsive:
- Flutter web app sends request
- Backend takes 30+ seconds to timeout
- Uncaught JavaScript errors occur
- UI appears to hang with no feedback

---

## ✅ The Solution

### Required Configuration

**In `render.yaml` (line 44-47):**
```yaml
- key: USE_PLACEHOLDERS_ONLY
  value: true  # MUST be true for free tier
```

**In Render Dashboard Environment Variables:**
```
USE_PLACEHOLDERS_ONLY=true
```

### Why This Works

1. **Skips Model Loading**: Backend doesn't attempt to load heavy image models
2. **Fast Generation**: Stories generate in 5-10 seconds instead of timing out
3. **Placeholder Images**: Uses professional-looking placeholder images instantly
4. **No Hanging**: Frontend gets quick responses, no timeout errors

---

## 📋 Configuration Checklist

### Backend Configuration

- [x] `render.yaml` has `USE_PLACEHOLDERS_ONLY=true`
- [x] `backend_fastapi/app/shared/config.py` defaults to `"true"`
- [x] Render dashboard environment variable set to `true`

### Verification Steps

1. **Check render.yaml**:
   ```bash
   grep -A 2 "USE_PLACEHOLDERS_ONLY" render.yaml
   ```
   Should show: `value: true`

2. **Check backend config.py**:
   ```bash
   grep -A 2 "use_placeholders_only" backend_fastapi/app/shared/config.py
   ```
   Should show default: `"true"`

3. **Test backend health**:
   ```bash
   curl https://your-app.onrender.com/health
   ```
   Should return quickly (< 5 seconds)

4. **Test story generation**:
   - Open app in browser
   - Generate a story
   - Should complete in 5-15 seconds
   - No hanging or timeout errors

---

## 🎨 What Are Placeholder Images?

Placeholder images are:
- ✅ Generated instantly (no AI model required)
- ✅ Professional gradient backgrounds
- ✅ Theme-appropriate colors
- ✅ Consistent with story theme
- ✅ Suitable for demos and testing

Example placeholders:
- **Ocean Dreams**: Blue gradient (#4A90E2 → #67B8F7)
- **Forest Friends**: Green gradient (#5CB85C → #8FD8A0)
- **Space Explorer**: Purple gradient (#9B59B6 → #C39BD3)

---

## 🚀 Upgrading to Real Image Generation

If you want to use real AI-generated images, you need:

### Option 1: Upgrade Render Plan

1. **Minimum**: Starter plan ($7/month, 512MB RAM)
   - Still might struggle with image models
   
2. **Recommended**: Standard plan ($25/month, 2GB RAM)
   - Can handle Stable Diffusion models
   - Better performance

3. **Update configuration**:
   ```yaml
   - key: USE_PLACEHOLDERS_ONLY
     value: false
   
   - key: LOCAL_IMAGE_ENABLED
     value: true
   ```

### Option 2: Use Cloud Image API

1. **Use external image API** (OpenAI DALL-E, Stability AI, etc.)
2. Set environment variables:
   ```yaml
   - key: USE_PLACEHOLDERS_ONLY
     value: false
   
   - key: IMAGE_API_KEY
     sync: false  # Set in Render dashboard
   
   - key: IMAGE_API_PROVIDER
     value: openai  # or stability, replicate, etc.
   ```

3. **Note**: External APIs cost money per generation

---

## 🐛 Troubleshooting

### Story Generation Hangs

**Symptoms**:
- Loading spinner never stops
- Browser console shows `Uncaught Error`
- Backend logs show "timeout" or "out of memory"

**Fix**:
1. Set `USE_PLACEHOLDERS_ONLY=true` in Render dashboard
2. Restart the service
3. Clear browser cache
4. Try story generation again

### Backend Takes 30+ Seconds

**Symptoms**:
- `/health` endpoint slow
- Story generation starts but times out
- Logs show "Attempting to load image pipeline"

**Fix**:
1. Verify `USE_PLACEHOLDERS_ONLY=true` is set
2. Check environment variables in Render dashboard
3. Restart service to apply changes
4. Monitor logs for "Using placeholder images" message

### JavaScript Errors in Browser

**Symptoms**:
```
main.dart.js:6610 Uncaught Error
    at Object.a (main.dart.js:4439:26)
```

**Fix**:
- This is caused by backend timeouts
- Follow steps above to fix backend configuration
- Frontend has been updated with better error handling (as of this fix)

---

## 📊 Performance Comparison

### With USE_PLACEHOLDERS_ONLY=true (Free Tier)
- Story generation: **5-10 seconds**
- Image generation: **< 1 second** (placeholders)
- Total time: **6-11 seconds**
- ✅ No timeouts
- ✅ No hanging

### With USE_PLACEHOLDERS_ONLY=false (Free Tier)
- Story generation: **5-10 seconds**
- Image model load attempt: **30 seconds** (timeout)
- Fallback to placeholders: **< 1 second**
- Total time: **36-41 seconds**
- ❌ Often causes timeouts
- ❌ UI appears to hang

### With Real Images (Paid Tier, 2GB+ RAM)
- Story generation: **5-10 seconds**
- Image model load (first time): **30-60 seconds**
- Image generation (4 images): **40-60 seconds**
- Total time: **45-70 seconds** (first story)
- Subsequent stories: **45-70 seconds**
- ✅ Real AI-generated images
- ⚠️ Slower but beautiful results

---

## 🎓 Best Practices

### For Demos and Testing
- ✅ Use `USE_PLACEHOLDERS_ONLY=true`
- ✅ Fast feedback loop
- ✅ No cost concerns
- ✅ Reliable performance

### For Production (Free Tier)
- ✅ Use `USE_PLACEHOLDERS_ONLY=true`
- ✅ Consider external image API for key stories
- ✅ Upgrade to paid tier when ready

### For Production (Paid Tier)
- ✅ Can set `USE_PLACEHOLDERS_ONLY=false`
- ✅ Use caching for generated images
- ✅ Consider CDN for image delivery
- ✅ Monitor RAM usage

---

## 📝 Related Files

- `render.yaml` - Render deployment configuration
- `backend_fastapi/app/shared/config.py` - Backend settings
- `backend_fastapi/app/core/local_services.py` - Image generation logic
- `dream-flow-app/app/lib/screens/create_story_screen.dart` - Frontend error handling
- `dream-flow-app/app/lib/screens/streaming_story_screen.dart` - Streaming error handling

---

## 🔗 Additional Resources

- [Render Free Tier Limits](https://render.com/docs/free)
- [Stable Diffusion Memory Requirements](https://github.com/AUTOMATIC1111/stable-diffusion-webui/wiki/Installation)
- [DreamFlow Deployment Guide](./COMPLETE_DEPLOYMENT_GUIDE.md)

---

**Last Updated**: January 12, 2026  
**Status**: ✅ All issues fixed
