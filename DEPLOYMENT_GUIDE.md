# Deployment Guide - Quick Start

This guide provides step-by-step instructions for deploying Dream Flow to production.

## Pre-Deployment Checklist

Run the deployment readiness verification:

```bash
python scripts/verify_deployment_readiness.py
```

This will verify:
- ✅ All required files are present
- ✅ Git repository is set up
- ✅ Configuration files are valid

## Step 1: Deploy Backend to Render

### 1.1 Create Render Account

1. Go to https://render.com
2. Sign up for a free account
3. Verify your email address

### 1.2 Connect GitHub Repository

1. In Render dashboard, click "New +" → "Blueprint"
2. Connect your GitHub account (if not already connected)
3. Select the repository containing Dream Flow
4. Render will automatically detect `render.yaml`

### 1.3 Review and Deploy

1. Review the service configuration:
   - Service name: `dream-flow-backend`
   - Plan: `starter` ($7/month)
   - Region: Choose closest to your users
   - Branch: `main` (or your production branch)
2. Click "Apply" to create the service
3. Wait for initial deployment (5-10 minutes)
4. Note the service URL (e.g., `https://dream-flow-backend.onrender.com`)

### 1.4 Configure Environment Variables

1. In Render dashboard, go to your service
2. Click "Environment" tab
3. Add all required variables (see `MANUAL_SETUP_STEPS.md` Section 4.3)
4. Click "Save Changes"
5. Service will automatically redeploy

### 1.5 Verify Deployment

```bash
python scripts/verify_backend_health.py https://your-service.onrender.com
```

Or manually check:
```bash
curl https://your-service.onrender.com/health
```

## Step 2: Set Up Payment Providers

### 2.1 Stripe Setup

1. Create account at https://stripe.com
2. Complete business verification
3. Create 4 subscription products (see `MANUAL_SETUP_STEPS.md` Section 1.1)
4. Get API keys and configure webhooks
5. Add keys to Render environment variables

### 2.2 RevenueCat Setup

1. Create account at https://revenuecat.com
2. Create project: "Dream Flow"
3. Connect App Store Connect and Google Play
4. Create products and get API key
5. Configure webhooks

## Step 3: Update Frontend Configuration

1. Update `config.json` with all real values
2. Run automation script:
   ```bash
   python setup_automation.py
   ```
3. Update Flutter build scripts with production values

## Step 4: Test Everything

1. Test backend health endpoint
2. Test story generation
3. Test payment flow (test mode)
4. Test webhook endpoints

## Troubleshooting

### Backend Not Deploying

- Check build logs in Render dashboard
- Verify Dockerfile is correct
- Ensure all dependencies are in requirements.txt

### Health Check Failing

- Verify all environment variables are set
- Check Render logs for errors
- Ensure `SUPABASE_SERVICE_ROLE_KEY` is set correctly

### Webhooks Not Working

- Verify webhook URL is publicly accessible
- Check webhook secret matches
- Review Stripe/RevenueCat webhook logs

## Next Steps

After successful deployment:
1. Configure webhook endpoints in Stripe and RevenueCat
2. Update frontend to use production backend URL
3. Complete app store setup
4. Begin beta testing

For detailed instructions, see `MANUAL_SETUP_STEPS.md`.

