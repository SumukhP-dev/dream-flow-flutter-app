# Render Deployment Debugging Guide

## 🔍 **Debugging Your Render Deployment**

### ✅ **Current Status - FIXED**
- ✅ render.yaml updated with all required environment variables
- ✅ Dockerfile updated to use PORT environment variable
- ✅ Health check endpoint configured
- ✅ Performance optimizations added for Render tiers

---

## 🚀 **Deployment Steps**

### 1. **Test Locally First**
```bash
# Test the Docker image locally
cd backend_fastapi
docker build -t dreamflow-backend .
docker run -p 8080:8080 -e PORT=8080 dreamflow-backend

# Test health endpoint
curl http://localhost:8080/health
```

### 2. **Push to GitHub**
```bash
git add render.yaml backend_fastapi/Dockerfile
git commit -m "Fix Render deployment configuration"
git push origin main
```

### 3. **Deploy to Render**
1. Go to https://dashboard.render.com
2. Click "New +" → "Blueprint"
3. Connect your GitHub repository
4. Render will detect `render.yaml`
5. **Set these required environment variables in Render dashboard:**
   ```
   HUGGINGFACE_API_TOKEN=hf_your_token_here
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_ANON_KEY=your_anon_key_here
   SUPABASE_SERVICE_ROLE_KEY=your_service_role_key_here
   ```
6. Click "Apply"

---

## 🐛 **Common Issues & Solutions**

### Issue 1: "Health check failed"
**Symptoms:** Deployment shows "Health check failed" error
**Causes:** 
- App crashing on startup
- Wrong health check path
- Port not binding correctly

**Solutions:**
```bash
# Check Render logs
# In Render dashboard: Your Service → Logs

# Common fixes:
1. Ensure PORT env var is being used (✅ Fixed)
2. Check if all required env vars are set
3. Verify app starts without errors
```

### Issue 2: "Memory limit exceeded"
**Symptoms:** Service crashes or restarts frequently
**Causes:** Too much memory usage for free tier

**Solutions:**
```env
# Add these to Render environment variables:
MAX_NEW_TOKENS=128
NUM_SCENES=1
FAST_MODE=true
LOW_MEMORY_MODE=true
USE_PLACEHOLDERS_ONLY=true  # Skip image generation
```

### Issue 3: "SUPABASE_SERVICE_ROLE_KEY not set"
**Symptoms:** Database connection errors
**Causes:** Missing environment variables

**Solutions:**
1. Go to Render dashboard → Your Service → Environment
2. Add Supabase variables (see required list above)
3. Redeploy service

### Issue 4: "HuggingFace API timeout"
**Symptoms:** Story generation fails
**Causes:** API timeouts or invalid token

**Solutions:**
```env
# Add to Render environment:
FAST_MODE=true
MAX_NEW_TOKENS=128
AI_INFERENCE_MODE=cloud_only
```

---

## 🔧 **Debugging Commands**

### Test Health Endpoint
```bash
curl https://your-app.onrender.com/health
# Expected: {"status":"ok","apps":["dreamflow","studio"]}
```

### Test API Documentation
```bash
# Visit in browser:
https://your-app.onrender.com/docs
```

### Test Story Generation
```bash
curl -X POST https://your-app.onrender.com/api/v1/story \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "A simple test story",
    "theme": "ocean",
    "target_length": 100,
    "num_scenes": 1
  }'
```

---

## 📊 **Performance Optimization**

### For Free Tier (512MB RAM)
```env
AI_INFERENCE_MODE=cloud_only
MAX_NEW_TOKENS=128
NUM_SCENES=1
FAST_MODE=true
LOW_MEMORY_MODE=true
USE_PLACEHOLDERS_ONLY=true
```

### For Starter Tier ($7/mo)
```env
AI_INFERENCE_MODE=cloud_first
MAX_NEW_TOKENS=256
NUM_SCENES=2
FAST_MODE=false
LOW_MEMORY_MODE=true
```

---

## 📋 **Pre-Deployment Checklist**

- [x] ✅ render.yaml configured
- [x] ✅ Dockerfile uses PORT env var
- [x] ✅ Health check endpoint works
- [x] ✅ All required env vars documented
- [ ] ⏳ GitHub repo connected to Render
- [ ] ⏳ Environment variables set in dashboard
- [ ] ⏳ Test deployment successful
- [ ] ⏳ Monitor logs for 1 hour

---

## 🆘 **Getting Help**

### 1. Check Render Logs First
- Render Dashboard → Your Service → Logs
- Look for ERROR messages during startup

### 2. Test Environment Variables
```bash
# In Render shell (if available):
printenv | grep -E "(SUPABASE|HUGGINGFACE|PORT)"
```

### 3. Verify Database Connection
```bash
# Test Supabase connection:
curl -H "apikey: YOUR_ANON_KEY" \
     https://your-project.supabase.co/rest/v1/
```

### 4. Check HuggingFace Token
```bash
# Verify token works:
curl -H "Authorization: Bearer hf_your_token" \
     https://api-inference.huggingface.co/models
```

---

## 🚀 **Expected Results**

**Successful Deployment:**
- Health check returns 200 OK
- API docs accessible at `/docs`
- Story generation works
- Logs show no startup errors

**Performance:**
- Cold start: 30-60 seconds (free tier)
- Warm response: 15-30 seconds
- Memory usage: 300-400MB

---

## 📞 **Support**

If you're still having issues:
1. Check Render logs for specific error messages
2. Verify all environment variables are set
3. Test locally with same configuration
4. Check this guide for common solutions

Your deployment should now work correctly! 🎉
