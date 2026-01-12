# Complete Deployment Guide: Supabase + FastAPI Backend (Render) + Flutter App

This guide covers deploying the Dream Flow application with all components.

---

## Part 1: Deploy Supabase Database (Cloud)

### Step 1.1: Create Supabase Project

1. **Go to Supabase**: https://supabase.com
2. **Sign up/Login** with GitHub or email
3. **Create New Project**:

   - Organization: Your organization
   - Name: `dream-flow-production`
   - Database Password: Generate a strong password (save it!)
   - Region: Choose closest to your users (e.g., `us-east-1`)
   - Pricing: Free tier is fine to start

4. **Wait for provisioning** (2-3 minutes)

### Step 1.2: Run Database Migrations

**Option A: Using Supabase Dashboard (Recommended)**

1. Go to your project dashboard
2. Navigate to **SQL Editor**
3. Run migrations in order from `backend_supabase/supabase/migrations/`:

   - `20240101000000_create_profiles.sql`
   - `20240101000001_create_rituals.sql`
   - `20240101000002_create_sessions.sql`
   - `20240101000003_create_session_assets.sql`
   - `20240101000004_create_session_feedback.sql`
   - `20240101000005_create_user_streaks.sql`
   - `20240101000006_create_analytics_views.sql`

4. For each file:
   - Copy the SQL content
   - Paste into SQL Editor
   - Click **Run** (or press `Ctrl/Cmd + Enter`)
   - Verify success message

**Option B: Using Supabase CLI**

```bash
# Install Supabase CLI
npm install -g supabase

# Login
supabase login

# Link to your project
cd backend_supabase
supabase link --project-ref your-project-ref

# Run migrations
supabase db push
```

### Step 1.3: Enable Required Extensions

1. Go to **Database > Extensions**
2. Enable these extensions:
   - ✅ `pg_cron` (for scheduled streak calculations)
   - ✅ `uuid-ossp` (for UUID generation)

### Step 1.4: Get API Credentials

1. Go to **Settings > API**
2. Copy and save these values:
   - **Project URL**: `https://xxxxx.supabase.co`
   - **Anon (public) key**: `eyJhbG...` (for client apps)
   - **Service role key**: `eyJhbG...` (for backend only - KEEP SECRET!)

---

## Part 2: Deploy FastAPI Backend to Render

### Step 2.1: Prepare Your Repository

Ensure your code is pushed to GitHub:

```bash
git add .
git commit -m "Prepare for deployment"
git push origin main
```

### Step 2.2: Update render.yaml Configuration

Your existing `render.yaml` is good, but let's add Klaviyo variables:

```yaml
services:
  - type: web
    name: dreamflow-backend
    env: docker
    region: oregon
    plan: free # or 'starter' for $7/month (better performance)
    dockerfilePath: ./backend_fastapi/Dockerfile
    dockerContext: ./backend_fastapi
    healthCheckPath: /health

    envVars:
      # Core Settings
      - key: AI_INFERENCE_MODE
        value: cloud_only

      # Supabase (Set these as secrets in Render dashboard)
      - key: SUPABASE_URL
        sync: false

      - key: SUPABASE_ANON_KEY
        sync: false

      - key: SUPABASE_SERVICE_ROLE_KEY
        sync: false

      # Hugging Face
      - key: HUGGINGFACE_API_TOKEN
        sync: false

      # Klaviyo (NEW - for your hackathon features)
      - key: KLAVIYO_ENABLED
        value: true

      - key: KLAVIYO_API_KEY
        sync: false

      # Redis (if using caching)
      - key: REDIS_URL
        value: redis://localhost:6379

      # Performance
      - key: FAST_MODE
        value: true

      - key: NUM_SCENES
        value: 2

    autoDeploy: true
    branch: main
```

### Step 2.3: Create Render Account & Deploy

1. **Go to Render**: https://render.com
2. **Sign up** with GitHub
3. **New > Blueprint**
4. **Connect your GitHub repository**
5. **Select repository**: `Dream_Flow_Flutter_App`
6. **Render detects** `render.yaml` automatically
7. **Review services**:
   - Service name: `dreamflow-backend`
   - Build command: Docker
   - Health check: `/health`
8. **Click "Apply"**

### Step 2.4: Add Environment Variables (Secrets)

1. Go to your deployed service dashboard
2. Click **Environment** tab
3. Add these secrets one by one:

```bash
# Supabase
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbG...  (from Supabase Settings > API)
SUPABASE_SERVICE_ROLE_KEY=eyJhbG...  (KEEP SECRET!)

# Hugging Face
HUGGINGFACE_API_TOKEN=hf_...  (from https://huggingface.co/settings/tokens)

# Klaviyo
KLAVIYO_API_KEY=pk_...  (from Klaviyo Account > Settings > API Keys)
KLAVIYO_ENABLED=true

# Optional: Stripe (for payments)
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...

# Optional: Sentry (for error tracking)
SENTRY_DSN=https://...@sentry.io/...
SENTRY_ENVIRONMENT=production
```

4. **Click "Save Changes"**
5. Render will automatically redeploy (5-10 minutes)

### Step 2.5: Verify Backend Deployment

Once deployed:

```bash
# Check health
curl https://dreamflow-backend.onrender.com/health

# Should return:
# {"status":"healthy","timestamp":"2026-01-12T..."}

# Check API docs
# Open: https://dreamflow-backend.onrender.com/docs
```

### Step 2.6: Verify Klaviyo API Configuration

1. Go to Klaviyo dashboard → **Settings > API Keys**
2. Confirm your **Private API Key** is copied
3. This key should already be set in Render as `KLAVIYO_API_KEY`
4. Your backend sends tracking events TO Klaviyo via API
5. No webhook configuration needed

**Note:** Dream Flow uses Klaviyo's REST API to send events (user signups, dream generations, etc.). Incoming webhooks from Klaviyo are not required for this integration.

---

## Part 3: Deploy Flutter Mobile App

### Step 3.1: Configure Backend URL in Flutter

Update your Flutter app configuration to use the production backend:

```dart
// lib/config.dart or similar
class AppConfig {
  static const String backendUrl = 'https://dreamflow-backend-9j4w.onrender.com';
  static const String supabaseUrl = 'https://dbpvmfglduprtbpaygmo.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_s1LUGs4Go22G_Z1y7WnQJw_nKcU5pZy';
}
```

Or use environment-specific configs:

```dart
// lib/config.dart
class AppConfig {
  static String get backendUrl {
    if (const bool.fromEnvironment('PRODUCTION')) {
      return 'https://dreamflow-backend.onrender.com';
    }
    return 'http://localhost:8000'; // Local development
  }
}
```

### Step 3.2: Build for Android

```bash
cd dream-flow-app/app

# Clean previous builds
flutter clean
flutter pub get

# Build release APK
flutter build apk --release

# Or build App Bundle for Play Store
flutter build appbundle --release

# Output location:
# APK: build/app/outputs/flutter-apk/app-release.apk
# AAB: build/app/outputs/bundle/release/app-release.aab
```

### Step 3.3: Build for iOS

```bash
cd dream-flow-app/app

# Clean previous builds
flutter clean
flutter pub get

# Build iOS release
flutter build ios --release

# Or create IPA for App Store
flutter build ipa --release

# Output location:
# build/ios/ipa/dream_flow.ipa
```

### Step 3.4: Build for Web (Optional)

If you want a web version:

```bash
cd dream-flow-app/app

# Build web
flutter build web --release

# Output location: build/web/
```

---

## Part 4: Deploy Flutter Web to Vercel (Optional)

If you built the web version:

### Step 4.1: Create vercel.json

Create `dream-flow-app/app/vercel.json`:

```json
{
  "version": 2,
  "buildCommand": "flutter build web --release",
  "outputDirectory": "build/web",
  "framework": null,
  "routes": [
    {
      "src": "/assets/(.*)",
      "dest": "/assets/$1"
    },
    {
      "src": "/(.*\\.(js|css|json|ico|png|jpg|jpeg|svg|woff|woff2|ttf))",
      "dest": "/$1"
    },
    {
      "src": "/(.*)",
      "dest": "/index.html"
    }
  ],
  "headers": [
    {
      "source": "/assets/(.*)",
      "headers": [
        {
          "key": "Cache-Control",
          "value": "public, max-age=31536000, immutable"
        }
      ]
    }
  ]
}
```

### Step 4.2: Deploy to Vercel

**Option A: Vercel Dashboard**

1. Go to https://vercel.com
2. Sign up/Login with GitHub
3. **New Project**
4. **Import Git Repository**
5. Select your repository
6. Configure:
   - Framework Preset: **Other**
   - Root Directory: `dream-flow-app/app`
   - Build Command: `flutter build web --release`
   - Output Directory: `build/web`
7. Add environment variables:
   ```
   SUPABASE_URL=https://xxxxx.supabase.co
   SUPABASE_ANON_KEY=eyJhbG...
   BACKEND_URL=https://dreamflow-backend.onrender.com
   ```
8. **Deploy**

**Option B: Vercel CLI**

```bash
# Install Vercel CLI
npm install -g vercel

# Login
vercel login

# Deploy from app directory
cd dream-flow-app/app
vercel --prod
```

---

## Part 5: Mobile App Distribution

### For Android (Google Play Store)

1. **Create Play Console Account**: https://play.google.com/console
2. **Create App**:
   - App name: Dream Flow
   - Default language: English
   - Type: App
   - Category: Education / Entertainment
3. **Upload AAB**:
   - Go to Production > Create Release
   - Upload `app-release.aab`
   - Fill in release notes
4. **Submit for Review**

### For iOS (Apple App Store)

1. **Create App Store Connect Account**: https://appstoreconnect.apple.com
2. **Create App**:
   - Name: Dream Flow
   - Primary Language: English
   - Bundle ID: (from your iOS project)
   - SKU: com.dreamflow.app
3. **Upload IPA**:
   - Use Transporter app or Xcode
   - Upload `dream_flow.ipa`
4. **Submit for Review**

### For Testing (Before Store Release)

**Android: Firebase App Distribution**

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login
firebase login

# Initialize
firebase init hosting

# Deploy APK for testing
firebase appdistribution:distribute \
  build/app/outputs/flutter-apk/app-release.apk \
  --app YOUR_FIREBASE_APP_ID \
  --groups testers
```

**iOS: TestFlight**

1. Upload IPA to App Store Connect
2. Go to TestFlight tab
3. Add external testers
4. Send invites

---

## Part 6: Post-Deployment Configuration

### 6.1 Update OAuth Redirect URLs (Supabase Auth)

1. Go to Supabase Dashboard
2. **Authentication > URL Configuration**
3. Add these redirect URLs:

   ```
   # Production
   https://dreamflow-backend.onrender.com/auth/callback

   # Vercel web (if deployed)
   https://dreamflow.vercel.app/auth/callback
   https://your-custom-domain.com/auth/callback

   # Mobile deep links
   dreamflow://auth/callback
   ```

### 6.2 Configure CORS (if needed)

In your FastAPI backend (`backend_fastapi/app/dreamflow/main.py`):

```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://dreamflow.vercel.app",
        "https://your-custom-domain.com",
        "https://dreamflow-backend.onrender.com",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

### 6.3 Set Up Custom Domain (Optional)

**For Render Backend:**

1. Render Dashboard > Service > Settings > Custom Domain
2. Add domain (e.g., `api.dreamflow.com`)
3. Update DNS records as instructed

**For Vercel Web:**

1. Vercel Dashboard > Project > Settings > Domains
2. Add domain (e.g., `app.dreamflow.com`)
3. Update DNS records

### 6.4 Enable HTTPS

- Render and Vercel both provide free SSL certificates automatically
- No additional configuration needed

---

## Part 7: Monitoring & Maintenance

### 7.1 Set Up Monitoring

**Render:**

- Dashboard shows CPU, memory, bandwidth
- View logs in real-time
- Set up alerts for downtime

**Supabase:**

- Monitor database size
- Check query performance
- Set up backup schedule (auto-enabled)

### 7.2 Enable Error Tracking

Add Sentry for error tracking:

```bash
# Add to requirements.txt (already there)
sentry-sdk[fastapi]==2.15.0

# Configure in backend
export SENTRY_DSN=https://...@sentry.io/...
```

### 7.3 Set Up Backup Schedule

**Supabase:**

- Auto-backup enabled on paid plans
- Free tier: Export manually weekly

**Render:**

- Set up Render Disks for persistent storage if needed
- Database backups handled by Supabase

---

## Part 8: Testing the Full Stack

### 8.1 Backend Health Check

```bash
curl https://dreamflow-backend.onrender.com/health
```

### 8.2 Test Story Generation

```bash
curl -X POST https://dreamflow-backend.onrender.com/api/v1/story \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_SUPABASE_JWT_TOKEN" \
  -d '{
    "prompt": "A calming bedtime story",
    "theme": "Ocean Adventures",
    "user_id": "YOUR_USER_UUID"
  }'
```

### 8.3 Test Mobile App

1. Install APK/IPA on test device
2. Sign up/Login
3. Generate a story
4. Verify assets load correctly
5. Check Supabase database for session record

---

## Troubleshooting

### Backend Not Deploying

**Check Docker build logs:**

1. Render Dashboard > Logs
2. Look for build errors
3. Common issues:
   - Missing dependencies in `requirements.txt`
   - Dockerfile path incorrect
   - Port binding issues (use `PORT` env var)

**Fix:**

```dockerfile
# backend_fastapi/Dockerfile
# Ensure PORT is read from environment
CMD uvicorn app.dreamflow.main:app --host 0.0.0.0 --port ${PORT:-8000}
```

### Health Check Failing

**Symptoms:** Render shows service as unhealthy

**Solutions:**

1. Verify `/health` endpoint exists
2. Check environment variables are set
3. Test locally with Docker:
   ```bash
   cd backend_fastapi
   docker build -t dreamflow-backend .
   docker run -p 8000:8000 --env-file .env dreamflow-backend
   curl http://localhost:8000/health
   ```

### Supabase Connection Issues

**Symptoms:** Backend can't connect to database

**Solutions:**

1. Verify `SUPABASE_URL` is correct
2. Check `SUPABASE_SERVICE_ROLE_KEY` is set (not anon key)
3. Test connection:
   ```python
   from supabase import create_client
   supabase = create_client(url, service_role_key)
   print(supabase.table('profiles').select('*').limit(1).execute())
   ```

### Flutter App Can't Reach Backend

**Symptoms:** Network errors in app

**Solutions:**

1. Check backend URL is correct in app config
2. Verify backend is deployed and healthy
3. Check CORS configuration
4. Test with curl/Postman first
5. Check mobile device network (try WiFi vs cellular)

### Klaviyo Integration Not Working

**Symptoms:** Events not appearing in Klaviyo

**Solutions:**

1. Verify `KLAVIYO_API_KEY` is set in Render (must be a **Private API Key**, not Public)
2. Check `KLAVIYO_ENABLED=true`
3. Test API key from command line:
   ```bash
   curl -X GET https://a.klaviyo.com/api/profiles \
     -H "Authorization: Klaviyo-API-Key YOUR_KEY" \
     -H "revision: 2024-10-15"
   ```
4. Check backend logs for Klaviyo errors
5. Verify events are being sent from your backend (check application logs)

---

## Cost Breakdown

### Free Tier (Getting Started)

- ✅ **Supabase Free**: 500MB database, 2GB bandwidth/month
- ✅ **Render Free**: 750 hours/month, sleeps after 15 min inactivity
- ✅ **Vercel Free**: 100GB bandwidth, unlimited deployments
- ⚠️ **Hugging Face**: Rate limited on free tier

**Total: $0/month** (with limitations)

### Production Tier (Recommended)

- ✅ **Supabase Pro**: $25/month (8GB database, better performance)
- ✅ **Render Starter**: $7/month (always on, better CPU/memory)
- ✅ **Vercel Pro**: $20/month (better bandwidth, analytics)
- ✅ **Klaviyo**: Free up to 250 contacts

**Total: ~$52/month**

---

## Next Steps After Deployment

1. ✅ Test all features end-to-end
2. ✅ Set up monitoring and alerts
3. ✅ Configure custom domains
4. ✅ Submit apps to stores
5. ✅ Set up CI/CD for automated deployments
6. ✅ Add analytics (Google Analytics, Mixpanel)
7. ✅ Configure email templates in Klaviyo
8. ✅ Set up backup and disaster recovery
9. ✅ Document API for team members
10. ✅ Plan for scaling (caching, CDN, etc.)

---

## Quick Reference: All URLs

```bash
# Production URLs
Backend API: https://dreamflow-backend.onrender.com
API Docs: https://dreamflow-backend.onrender.com/docs
Health Check: https://dreamflow-backend.onrender.com/health

# Supabase
Dashboard: https://supabase.com/dashboard/project/YOUR_PROJECT_ID
Database URL: https://xxxxx.supabase.co
Studio: https://supabase.com/dashboard/project/YOUR_PROJECT_ID/editor

# Admin Dashboards
Render: https://dashboard.render.com
Supabase: https://supabase.com/dashboard
Klaviyo: https://www.klaviyo.com/settings/account/api-keys
Stripe: https://dashboard.stripe.com
```

---

**Deployment Complete! 🚀**

You now have:

- ✅ Supabase database with all migrations
- ✅ FastAPI backend deployed on Render
- ✅ Flutter mobile apps ready for stores
- ✅ (Optional) Flutter web app on Vercel
- ✅ Klaviyo integration active
- ✅ Full monitoring and error tracking

Need help? Check the troubleshooting section or review the logs in each platform's dashboard.
