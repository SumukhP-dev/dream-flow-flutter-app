# Azure Deployment Guide

This guide provides step-by-step instructions for deploying Dream Flow backend to Azure App Service.

## Prerequisites

- Azure account with active subscription
- Azure CLI installed and configured (`az login`)
- GitHub repository with code pushed
- Docker installed (for local testing)

## Option 1: Deploy via GitHub Actions (Recommended)

### Step 1: Configure GitHub Secrets

Add the following secrets to your GitHub repository:

**Azure Credentials**:

1. Create Azure Service Principal:
   ```bash
   az ad sp create-for-rbac --name "dream-flow-github-actions" \
     --role contributor \
     --scopes /subscriptions/{subscription-id} \
     --sdk-auth
   ```
2. Copy the JSON output and add as `AZURE_CREDENTIALS` secret in GitHub

3. Add `AZURE_SUBSCRIPTION_ID` secret

**Azure Container Registry (Optional)**:

- `AZURE_CONTAINER_REGISTRY` - ACR URL
- `AZURE_CONTAINER_REGISTRY_USERNAME` - ACR username
- `AZURE_CONTAINER_REGISTRY_PASSWORD` - ACR password

**Application Secrets**:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `AZURE_CONTENT_SAFETY_ENABLED` (set to `true`)
- `AZURE_CONTENT_SAFETY_ENDPOINT`
- `AZURE_CONTENT_SAFETY_KEY`
- `AZURE_COMPUTER_VISION_ENABLED` (set to `true`)
- `AZURE_COMPUTER_VISION_ENDPOINT`
- `AZURE_COMPUTER_VISION_KEY`

### Step 2: Deploy

1. Push to `main` branch to trigger automatic deployment
2. Or manually trigger workflow from GitHub Actions tab
3. Monitor deployment in GitHub Actions logs

## Option 2: Deploy via Azure CLI

### Step 1: Create Resource Group

```bash
az group create --name dream-flow-rg --location eastus
```

### Step 2: Deploy Bicep Template

```bash
az deployment group create \
  --resource-group dream-flow-rg \
  --template-file azure/app-service.bicep \
  --parameters \
    appServiceName=dream-flow-backend \
    appServicePlanName=dream-flow-app-service-plan \
    skuName=B1
```

### Step 3: Build and Push Docker Image

**Option A: Use Azure Container Registry**

```bash
# Create ACR
az acr create --resource-group dream-flow-rg \
  --name dreamflowregistry --sku Basic

# Login to ACR
az acr login --name dreamflowregistry

# Build and push image
az acr build --registry dreamflowregistry \
  --image dream-flow-backend:latest \
  --file backend_fastapi/Dockerfile ./backend_fastapi
```

**Option B: Use Docker Hub**

```bash
docker build -t yourusername/dream-flow-backend:latest ./backend_fastapi
docker push yourusername/dream-flow-backend:latest
```

### Step 4: Configure App Service

**Set Docker image**:

```bash
az webapp config container set \
  --resource-group dream-flow-rg \
  --name dream-flow-backend \
  --docker-custom-image-name dreamflowregistry.azurecr.io/dream-flow-backend:latest \
  --docker-registry-server-url https://dreamflowregistry.azurecr.io \
  --docker-registry-server-user dreamflowregistry \
  --docker-registry-server-password $(az acr credential show --name dreamflowregistry --query "passwords[0].value" -o tsv)
```

**Configure environment variables**:

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

### Step 5: Verify Deployment

```bash
# Check app service status
az webapp show --resource-group dream-flow-rg --name dream-flow-backend --query state

# Test health endpoint
curl https://dream-flow-backend.azurewebsites.net/health

# View logs
az webapp log tail --resource-group dream-flow-rg --name dream-flow-backend
```

## Option 3: Deploy via Azure Portal

### Step 1: Create App Service

1. Go to Azure Portal → Create a resource
2. Search for "Web App"
3. Click "Create"
4. Fill in details:
   - Subscription: Your subscription
   - Resource Group: Create new or use existing
   - Name: `dream-flow-backend`
   - Publish: Docker Container
   - Operating System: Linux
   - Region: Choose closest to users
   - Pricing Plan: Basic (B1) or Standard (S1)

### Step 2: Configure Container

1. In App Service → Deployment Center
2. Source: Container Registry
3. Registry: Azure Container Registry or Docker Hub
4. Image: `dream-flow-backend:latest`

### Step 3: Configure Environment Variables

1. Go to App Service → Configuration → Application settings
2. Add all required environment variables (see Step 4 in Option 2)

### Step 4: Enable Application Insights

1. Go to App Service → Application Insights
2. Click "Turn on Application Insights"
3. Create new or use existing Application Insights resource

## Post-Deployment

### Verify Deployment

1. **Health Check**:

   ```bash
   curl https://dream-flow-backend.azurewebsites.net/health
   ```

2. **API Documentation**:

   - Swagger UI: `https://dream-flow-backend.azurewebsites.net/docs`
   - ReDoc: `https://dream-flow-backend.azurewebsites.net/redoc`

3. **Test Story Generation**:
   ```bash
   curl -X POST https://dream-flow-backend.azurewebsites.net/api/v1/story \
     -H "Content-Type: application/json" \
     -d '{"prompt": "A peaceful bedtime story", "theme": "Calm Focus"}'
   ```

### Monitor Application

1. **Application Insights**:

   - Go to Azure Portal → Application Insights
   - View performance metrics, requests, exceptions

2. **App Service Logs**:

   - Go to App Service → Log stream
   - View real-time logs

3. **Metrics**:
   - Go to App Service → Metrics
   - Monitor CPU, memory, requests

## Scaling

### Manual Scaling

```bash
az appservice plan update \
  --resource-group dream-flow-rg \
  --name dream-flow-app-service-plan \
  --sku S1  # Upgrade to Standard tier
```

### Auto-scaling (Standard Tier)

1. Go to App Service Plan → Scale out
2. Enable autoscale
3. Configure rules based on CPU/Memory metrics
4. Set instance limits (min: 1, max: 10)

## Custom Domain

### Add Custom Domain

1. Go to App Service → Custom domains
2. Click "Add custom domain"
3. Enter your domain name
4. Follow DNS configuration instructions

### SSL Certificate

1. Go to App Service → TLS/SSL settings
2. Click "Create App Service Managed Certificate"
3. Select your custom domain
4. SSL binding will be created automatically

## Troubleshooting

### Container Fails to Start

1. Check logs: `az webapp log tail --resource-group dream-flow-rg --name dream-flow-backend`
2. Verify Docker image is accessible
3. Check environment variables are set correctly
4. Review Application Insights for errors

### 502 Bad Gateway

- Usually means container crashed
- Check logs for Python errors
- Verify all required environment variables are set
- Check container has enough memory (upgrade plan if needed)

### Slow Response Times

1. Upgrade to Standard tier for better performance
2. Enable Always On (already enabled in Bicep template)
3. Review Application Insights for slow requests
4. Consider enabling Application Insights Profiler

### Environment Variables Not Working

1. Verify variables are set in App Service Configuration
2. Restart app service after adding variables
3. Check variable names match `config.py` expectations
4. Use Azure Key Vault references for secrets

## Cost Optimization

1. **Use Free Tier for Azure AI Services**: First few thousand requests are free
2. **Start with Basic (B1) Plan**: ~$13/month, upgrade when needed
3. **Enable Auto-shutdown**: For development/test environments
4. **Monitor Usage**: Set up budget alerts in Azure Portal
5. **Use Reserved Instances**: For production (1-3 year commitments get discounts)

## Security Best Practices

1. **Use Azure Key Vault**: Store secrets in Key Vault, reference in App Settings
2. **Enable HTTPS Only**: Already configured in Bicep template
3. **Enable Managed Identity**: For secure access to other Azure resources
4. **Enable Application Insights**: For security monitoring
5. **Regular Updates**: Keep Docker image and dependencies updated

## Next Steps

1. Set up custom domain and SSL
2. Configure auto-scaling for production
3. Set up staging slot for blue-green deployments
4. Configure backup and disaster recovery
5. Set up monitoring alerts

For more details, see:

- `azure/README.md` - Detailed Azure deployment guide
- `docs/AZURE_INTEGRATION.md` - Azure services integration guide
- Azure Portal documentation
