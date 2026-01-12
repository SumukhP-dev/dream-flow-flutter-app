# Azure Deployment Guide

This directory contains Azure deployment configuration for Dream Flow backend.

⚠️ **Important**: Azure App Service is **OPTIONAL** and only needed if you want to deploy a shared cloud backend server. If your backend runs on-device (bundled in the mobile app), you do NOT need Azure App Service.

## When to Use Azure App Service

✅ **Use Azure App Service if**:
- You want a shared backend server accessible by multiple users
- You're deploying a web dashboard that needs a backend API
- You need centralized processing and storage
- You want to offload processing from mobile devices

❌ **Do NOT use Azure App Service if**:
- Your backend is bundled into the mobile app and runs on user's phone
- All processing happens locally on the device
- You want offline-first functionality
- You're using the on-device architecture (primary architecture)

## Files

- `app-service.bicep` - Infrastructure as Code (IaC) template for Azure App Service
- `deploy-app-service.yml` - GitHub Actions workflow for automated deployment
- `README.md` - This file

## Prerequisites

1. **Azure Account** with active subscription
2. **Azure CLI** installed and configured
3. **GitHub Actions** secrets configured (see below)
4. **Azure Container Registry (optional)** - for container image storage

## Quick Start

### Option 1: Deploy via GitHub Actions (Recommended)

1. **Configure GitHub Secrets**

   Add the following secrets to your GitHub repository (Settings → Secrets and variables → Actions):

   **Azure Credentials:**

   - `AZURE_CREDENTIALS` - Azure service principal credentials (JSON)
   - `AZURE_SUBSCRIPTION_ID` - Azure subscription ID

   **Azure Container Registry (if using ACR):**

   - `AZURE_CONTAINER_REGISTRY` - ACR URL (e.g., `myregistry.azurecr.io`)
   - `AZURE_CONTAINER_REGISTRY_USERNAME` - ACR username
   - `AZURE_CONTAINER_REGISTRY_PASSWORD` - ACR password

   **Application Secrets:**

   - `SUPABASE_URL` - Supabase project URL
   - `SUPABASE_ANON_KEY` - Supabase anon key
   - `SUPABASE_SERVICE_ROLE_KEY` - Supabase service role key (keep secret!)

   **Azure AI Services (for Imagine Cup):**

   - `AZURE_CONTENT_SAFETY_ENABLED` - Set to `true` to enable
   - `AZURE_CONTENT_SAFETY_ENDPOINT` - Azure Content Safety endpoint URL
   - `AZURE_CONTENT_SAFETY_KEY` - Azure Content Safety API key
   - `AZURE_COMPUTER_VISION_ENABLED` - Set to `true` to enable
   - `AZURE_COMPUTER_VISION_ENDPOINT` - Azure Computer Vision endpoint URL
   - `AZURE_COMPUTER_VISION_KEY` - Azure Computer Vision API key

2. **Create Azure Service Principal**

   ```bash
   az ad sp create-for-rbac --name "dream-flow-github-actions" \
     --role contributor \
     --scopes /subscriptions/{subscription-id} \
     --sdk-auth
   ```

   Copy the JSON output and add it as `AZURE_CREDENTIALS` secret in GitHub.

3. **Deploy**

   - Push to `main` branch to trigger automatic deployment
   - Or manually trigger workflow from GitHub Actions tab

### Option 2: Deploy via Azure CLI

1. **Create Resource Group**

   ```bash
   az group create --name dream-flow-rg --location eastus
   ```

2. **Deploy Bicep Template**

   ```bash
   az deployment group create \
     --resource-group dream-flow-rg \
     --template-file azure/app-service.bicep \
     --parameters appServiceName=dream-flow-backend
   ```

3. **Build and Push Docker Image** (if using ACR)

   ```bash
   # Login to ACR
   az acr login --name <your-acr-name>

   # Build and push
   docker build -t <your-acr-name>.azurecr.io/dream-flow-backend:latest ./backend_fastapi
   docker push <your-acr-name>.azurecr.io/dream-flow-backend:latest
   ```

4. **Configure App Settings**

   ```bash
   az webapp config appsettings set \
     --resource-group dream-flow-rg \
     --name dream-flow-backend \
     --settings \
       PYTHONUNBUFFERED=1 \
       ASSET_DIR=/app/storage \
       SUPABASE_URL="https://your-project.supabase.co" \
       SUPABASE_ANON_KEY="your-anon-key" \
       SUPABASE_SERVICE_ROLE_KEY="your-service-role-key" \
       BACKEND_URL="https://dream-flow-backend.azurewebsites.net" \
       AZURE_CONTENT_SAFETY_ENABLED="true" \
       AZURE_CONTENT_SAFETY_ENDPOINT="https://your-region.api.cognitive.microsoft.com/" \
       AZURE_CONTENT_SAFETY_KEY="your-key" \
       AZURE_COMPUTER_VISION_ENABLED="true" \
       AZURE_COMPUTER_VISION_ENDPOINT="https://your-region.cognitiveservices.azure.com/" \
       AZURE_COMPUTER_VISION_KEY="your-key"
   ```

## Azure App Service Configuration

### Recommended Settings

- **Tier**: Basic (B1) for development, Standard (S1) for production
- **Operating System**: Linux
- **Runtime Stack**: Docker Container
- **Always On**: Enabled
- **HTTPS Only**: Enabled

### Scaling

For production workloads, consider:

- **App Service Plan**: Standard (S1) or higher
- **Auto-scaling**: Configure based on CPU/Memory metrics
- **Multiple instances**: For high availability

### Environment Variables

All sensitive environment variables should be:

1. **Set via Azure Portal** (recommended for secrets)
2. **Or stored in Azure Key Vault** and referenced

See `backend_fastapi/app/shared/config.py` for all required environment variables.

## Monitoring

The Bicep template optionally creates Application Insights for monitoring:

- Application performance monitoring
- Request tracking
- Error logging
- Dependency tracking

Access Application Insights in Azure Portal under your resource group.

## Cost Estimation

**Basic Tier (B1)** - Development:

- ~$13-15/month
- 1.75 GB RAM
- 1 Core

**Standard Tier (S1)** - Production:

- ~$70/month
- 1.75 GB RAM
- 1 Core
- Auto-scaling support

**Additional Costs:**

- Azure Content Safety: Pay-per-use
- Azure Computer Vision: Pay-per-use
- Azure Container Registry: ~$5/month (if used)
- Application Insights: Free tier available

## Troubleshooting

### Common Issues

1. **Container fails to start**

   - Check Application Insights logs
   - Verify environment variables are set correctly
   - Check Docker image is accessible

2. **Missing environment variables**

   - Verify all required variables are set in App Settings
   - Check variable names match `config.py` expectations

3. **Azure AI services not working**
   - Verify endpoints and keys are correct
   - Check service is enabled in Azure Portal
   - Review Application Insights for API errors

### View Logs

```bash
az webapp log tail \
  --resource-group dream-flow-rg \
  --name dream-flow-backend
```

Or use Azure Portal → App Service → Log stream

## Next Steps

1. Set up Azure Key Vault for secure secret storage
2. Configure custom domain
3. Set up SSL certificate
4. Configure auto-scaling rules
5. Set up staging slots for blue-green deployments
