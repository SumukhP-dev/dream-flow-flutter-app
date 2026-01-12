# Environment Variables Status

**Last Updated**: 2026-01-09  
**Location**: `backend_fastapi/.env`

---

## ✅ Currently Configured

### Required Core Variables

- ✅ `SUPABASE_URL` - Configured
- ✅ `SUPABASE_ANON_KEY` (via `YOUR_SUPABASE_ANON_KEY`) - Configured
- ✅ `SUPABASE_SERVICE_ROLE_KEY` - Configured (REQUIRED - app will fail without this)
- ✅ `BACKEND_URL` - Configured (`http://localhost:8080`)

### Local Inference Configuration

- ✅ `LOCAL_INFERENCE=true` - Enabled
- ✅ `INFERENCE_VERSION=local` - Set to local mode
- ✅ `LOCAL_MODEL_PATH=./models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf` - Configured
- ✅ `LOCAL_STORY_MODEL=tinyllama` - Configured
- ✅ `EDGE_TTS_VOICE=en-US-AriaNeural` - Configured
- ✅ `LOCAL_IMAGE_ENABLED=true` - Enabled
- ✅ `LOCAL_IMAGE_MODEL=runwayml/stable-diffusion-v1-5` - Production-ready default (requires accepted HF license + token)
- ✅ Lightweight fallback handled automatically (`stabilityai/sd-turbo` for low-memory mode)
- ✅ `LOCAL_VIDEO_ENABLED=false` - Disabled (by design)

### Image Generation Settings

- ✅ `IMAGE_RESOLUTION=256x256` - Configured
- ✅ `IMAGE_STEPS=4` - Configured
- ✅ `USE_PLACEHOLDERS_ONLY=false` - Disabled (using real images)
- ✅ `NUM_SCENES=2` - Configured

### Performance Optimization

- ✅ `LOW_MEMORY_MODE=true` - Enabled
- ✅ `FAST_MODE=true` - Enabled
- ✅ `STORY_MODEL_USE_GPU=false` - CPU mode
- ✅ `STORY_MODEL_GPU_LAYERS=0` - CPU mode

### Klaviyo Integration

- ✅ `KLAVIYO_API_KEY` - Configured
- ✅ `KLAVIYO_ENABLED=true` - Enabled

### Azure Content Safety

- ✅ `AZURE_CONTENT_SAFETY_ENABLED=true` - Enabled
- ✅ `AZURE_CONTENT_SAFETY_ENDPOINT` - Configured
- ✅ `AZURE_CONTENT_SAFETY_KEY` - Configured

### Azure Computer Vision

- ✅ `AZURE_COMPUTER_VISION_ENABLED=true` - Enabled
- ✅ `AZURE_COMPUTER_VISION_ENDPOINT` - Configured
- ✅ `AZURE_COMPUTER_VISION_KEY` - Configured

### Payment Integration

- ✅ `STRIPE_SECRET_KEY` - Configured (test key)
- ✅ `STRIPE_WEBHOOK_SECRET` - Partially configured (`whsec_...`)
- ⚠️ `STRIPE_PUBLISHABLE_KEY` - **MISSING** (needed for frontend)
- ⚠️ `STRIPE_PREMIUM_MONTHLY_PRICE_ID` - **MISSING**
- ⚠️ `STRIPE_PREMIUM_ANNUAL_PRICE_ID` - **MISSING**
- ⚠️ `STRIPE_FAMILY_MONTHLY_PRICE_ID` - **MISSING**
- ⚠️ `STRIPE_FAMILY_ANNUAL_PRICE_ID` - **MISSING**

### Optional Services

- ✅ `HUGGINGFACE_API_TOKEN` - Configured (fallback if local inference fails)
- ⚠️ `SENTRY_DSN` - **EMPTY** (error tracking disabled)

---

## ❌ Missing/Incomplete Variables

### High Priority (Required for Full Functionality)

#### 1. Stripe Configuration (For Payments)

```bash
# Frontend needs this to process payments
STRIPE_PUBLISHABLE_KEY=pk_test_...

# Get these from Stripe Dashboard > Products > Pricing
STRIPE_PREMIUM_MONTHLY_PRICE_ID=price_...
STRIPE_PREMIUM_ANNUAL_PRICE_ID=price_...
STRIPE_FAMILY_MONTHLY_PRICE_ID=price_...
STRIPE_FAMILY_ANNUAL_PRICE_ID=price_...

# Complete webhook secret (currently partial)
STRIPE_WEBHOOK_SECRET=whsec_...
```

**How to Get**:

1. Go to Stripe Dashboard > Developers > API Keys
2. Copy publishable key (`pk_test_...`)
3. Go to Products > Create subscription products
4. Copy Price IDs from each product
5. Go to Developers > Webhooks > Add endpoint
6. Copy webhook signing secret

---

#### 2. Sentry Error Tracking (Recommended)

```bash
# Get from https://sentry.io > Project Settings > Client Keys (DSN)
SENTRY_DSN=https://xxx@sentry.io/xxx
SENTRY_ENVIRONMENT=development  # or production
SENTRY_TRACES_SAMPLE_RATE=0.2  # Already has default, but can override
```

**Status**: Currently empty - error tracking is disabled

---

### Medium Priority (Optional Features)

#### 3. CDN Configuration (For Production)

```bash
CDN_ENABLED=true
CDN_URL=https://your-cdn-domain.com
```

**When Needed**: Production deployments with high traffic

---

#### 3. YouTube Automation (If Using)

```bash
YOUTUBE_CLIENT_ID=xxx
YOUTUBE_CLIENT_SECRET=xxx
YOUTUBE_REFRESH_TOKEN=xxx
YOUTUBE_CHANNEL_ID=xxx
```

**When Needed**: Automated video uploads to YouTube  
**Status**: Feature is implemented but needs OAuth setup

---

#### 4. Azure Blob Storage (Alternative to Supabase Storage)

```bash
AZURE_BLOB_STORAGE_ENABLED=false  # Keep false if using Supabase
AZURE_STORAGE_CONNECTION_STRING=DefaultEndpointsProtocol=...
AZURE_BLOB_STORAGE_CONTAINER_NAME=dream-flow-assets
```

**When Needed**: Only if you want to use Azure Blob Storage instead of Supabase  
**Status**: Currently using Supabase, so not needed

---

#### 5. Azure Key Vault (For Production Secret Management)

```bash
AZURE_KEY_VAULT_URL=https://your-vault.vault.azure.net/
AZURE_KEY_VAULT_SECRET_NAME=supabase-service-role-key  # Optional, has default
```

**When Needed**: Production deployments on Azure  
**Status**: Currently using environment variables directly

---

### Low Priority (Advanced/Experimental)

#### 6. Apple Intelligence API (Not Yet Available)

```bash
APPLE_INTELLIGENCE_API_KEY=xxx  # Not available yet
ENABLE_APPLE_INTELLIGENCE=false
```

**Status**: API not yet released by Apple

---

#### 7. Admin Configuration

```bash
ADMIN_USER_IDS=user-id-1,user-id-2  # Comma-separated list of admin UUIDs
```

**When Needed**: For admin-only endpoints  
**Status**: Optional - can be added when needed

---

#### 11. Asset Retention

```bash
ASSET_RETENTION_DAYS=7  # Default, can override
```

**Status**: Has default value of 7 days

---

## 📋 Quick Reference: Required vs Optional

### ✅ Required (App Won't Start Without)

- `SUPABASE_SERVICE_ROLE_KEY` - **REQUIRED** (app will crash without this)

### ⚠️ Recommended (App Works But Missing Features)

- `STRIPE_PUBLISHABLE_KEY` - Needed for frontend payment processing
- `STRIPE_*_PRICE_ID` - Needed for subscription products
- `SENTRY_DSN` - Needed for error tracking

### 🔵 Optional (Enables Additional Features)

- `CDN_*` - For production CDN
- `GOOGLE_CLOUD_*` - For Google Vertex AI
- `YOUTUBE_*` - For YouTube automation
- `AZURE_BLOB_STORAGE_*` - Alternative storage
- `AZURE_KEY_VAULT_*` - Production secret management

### 💚 Already Configured (No Action Needed)

- Supabase configuration ✅
- Klaviyo integration ✅
- Azure Content Safety ✅
- Azure Computer Vision ✅
- Local inference settings ✅
- Performance optimization settings ✅

---

## 🎯 Action Items

### Immediate (High Priority)

1. **Complete Stripe Configuration**:

   - Add `STRIPE_PUBLISHABLE_KEY` to `.env`
   - Create subscription products in Stripe Dashboard
   - Add all 4 Price IDs to `.env`
   - Complete `STRIPE_WEBHOOK_SECRET` value

2. **Enable Sentry Error Tracking**:
   - Create Sentry account (if not already)
   - Add project and get DSN
   - Add `SENTRY_DSN` to `.env`

### Optional (When Needed)

3. **CDN Setup** (for production):

   - Set up CDN (Cloudflare, AWS CloudFront, etc.)
   - Add `CDN_ENABLED=true` and `CDN_URL=...`

4. **Google Cloud Setup** (if switching from local inference):
   - Create GCP project
   - Create service account
   - Download credentials JSON
   - Add `GOOGLE_CLOUD_PROJECT` and `GOOGLE_APPLICATION_CREDENTIALS`

---

## 📝 Notes

1. **Supabase Keys**: The app uses both `SUPABASE_*` and `YOUR_SUPABASE_*` variants for backwards compatibility. Both are configured.

2. **Local Inference**: Currently fully configured for local CPU-based inference. No cloud API keys needed unless you want to use them.

3. **Stripe**: Test keys are configured. Switch to live keys (`sk_live_...` and `pk_live_...`) for production.

4. **Security**: Never commit `.env` file to git. It's already in `.gitignore`.

5. **Environment-Specific**: Consider using different `.env` files for development, staging, and production:
   - `.env.development`
   - `.env.staging`
   - `.env.production`
