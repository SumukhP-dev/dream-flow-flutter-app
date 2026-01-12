# Vercel Deployment Guide for Dream Flow Flutter Web

## Quick Setup

### 1. Connect Repository to Vercel

1. Go to [Vercel](https://vercel.com)
2. Click "Add New Project"
3. Import your GitHub repository: `SumukhP-dev/dream-flow-flutter-app`

### 2. Configure Project Settings

**Root Directory:** `dream-flow-app/app`

**Framework Preset:** Other (Flutter is not a default option)

**Build & Output Settings:**
- Build Command: (Leave empty - uses `vercel.json` config)
- Output Directory: (Leave empty - uses `vercel.json` config)
- Install Command: (Leave empty - uses `vercel.json` config)

### 3. Add Environment Variables

Go to **Settings → Environment Variables** and add these for **Production**, **Preview**, and **Development**:

#### Required Variables:

```bash
BACKEND_URL=https://dreamflow-backend-9j4w.onrender.com
SUPABASE_URL=https://dbpvmfglduprtbpaygmo.supabase.co
SUPABASE_ANON_KEY=your_supabase_anon_key_here
```

#### Optional Variables:

```bash
SENTRY_DSN=your_sentry_dsn_here
ENVIRONMENT=production
```

### 4. Deploy

Click **Deploy** and wait 10-15 minutes for the first build (Flutter SDK needs to be cloned).

---

## How It Works

The `vercel.json` configuration:

1. **Installs Flutter SDK** on the build server (cached for subsequent builds)
2. **Enables Flutter web** support
3. **Installs dependencies** via `flutter pub get`
4. **Builds the web app** with environment variables passed via `--dart-define`
5. **Serves** the static files from `build/web/`
6. **Routes** all requests to `index.html` for SPA routing

---

## Troubleshooting

### Build Fails: "Flutter command not found"

**Cause:** The Flutter SDK installation in the build command failed.

**Solution:** The build command should automatically install Flutter. If it keeps failing, try:
1. Check Vercel build logs for specific errors
2. Verify the build command in `vercel.json` is not truncated

### Build Fails: "Failed to load asset"

**Cause:** Missing asset files (like .env files that are gitignored).

**Solution:** The `.env` files are commented out in `pubspec.yaml`. The app uses `--dart-define` variables instead for web builds. Make sure environment variables are set in Vercel.

### Build Timeout

**Cause:** First build clones entire Flutter SDK (~1GB).

**Solution:**
1. Wait for the initial build (10-15 minutes)
2. Subsequent builds will be faster (~3-5 minutes) as Flutter is cached
3. Consider using Vercel Pro for longer build timeouts

### App Loads but Can't Connect to Backend

**Cause:** Environment variables not passed correctly or backend is down.

**Solution:**
1. Check Vercel dashboard: Settings → Environment Variables
2. Ensure `BACKEND_URL` is set correctly
3. Test backend health: `curl https://dreamflow-backend-9j4w.onrender.com/health`
4. Check browser console for specific errors

### CORS Errors

**Cause:** Backend not configured to accept requests from your Vercel domain.

**Solution:** Update CORS settings in your FastAPI backend (`backend_fastapi/app/main.py`):

```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://your-app.vercel.app",
        "https://dreamflow.vercel.app",
        # Add your custom domain
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

---

## Custom Domain Setup

1. Go to **Project Settings → Domains**
2. Add your custom domain (e.g., `app.dreamflow.com`)
3. Add DNS records as instructed by Vercel
4. SSL certificate is automatically provisioned

---

## Performance Optimization

The current `vercel.json` already includes:

✅ **Aggressive caching** for assets (1 year)
✅ **SPA routing** via rewrites
✅ **Immutable cache headers** for static files

### Additional Optimizations:

1. **Enable Gzip/Brotli** (automatic on Vercel)
2. **Use Vercel Analytics** for performance monitoring
3. **Consider Vercel Pro** for better bandwidth and build times

---

## Monitoring

### View Build Logs

1. Go to **Deployments** tab
2. Click on a deployment
3. View **Building** logs for any errors

### View Runtime Logs

Flutter web apps are static (no server-side code), so runtime logs are:
- Browser console (for client-side errors)
- Sentry (if configured) for error tracking

---

## CI/CD

Vercel automatically:
- ✅ Deploys on every push to `main` branch (Production)
- ✅ Creates preview deployments for pull requests
- ✅ Runs builds on every commit

No additional CI/CD setup required!

---

## Cost

- **Hobby Plan (Free):**
  - 100GB bandwidth/month
  - 6,000 build minutes/month
  - Unlimited deployments
  - Good for testing and small traffic

- **Pro Plan ($20/month):**
  - 1TB bandwidth/month
  - 24,000 build minutes/month
  - Analytics included
  - Better for production

---

## Support

If you encounter issues:

1. Check Vercel build logs
2. Test locally: `flutter build web --release --dart-define=BACKEND_URL=...`
3. Review this guide's troubleshooting section
4. Check Vercel status: https://www.vercel-status.com/
