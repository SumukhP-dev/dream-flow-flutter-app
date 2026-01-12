// Azure Bicep template for Dream Flow Backend App Service deployment
// This template creates an Azure App Service for containerized deployment

@description('The name of the App Service plan')
param appServicePlanName string = 'dream-flow-app-service-plan'

@description('The name of the App Service')
param appServiceName string = 'dream-flow-backend'

@description('The location for all resources')
param location string = resourceGroup().location

@description('The SKU for the App Service plan')
param skuName string = 'B1' // Basic tier - can be upgraded to Standard (S1) for production

@description('Docker image name (from Azure Container Registry or Docker Hub)')
param dockerImage string = 'dreamflow/backend:latest'

@description('Docker registry URL (optional, for ACR)')
param dockerRegistryUrl string = ''

@description('Docker registry username (optional)')
param dockerRegistryUsername string = ''

@description('Enable Application Insights')
param enableApplicationInsights bool = true

@description('Application Insights name')
param applicationInsightsName string = 'dream-flow-insights'

// App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: appServicePlanName
  location: location
  kind: 'linux'
  properties: {
    reserved: true // Required for Linux App Service
  }
  sku: {
    name: skuName
  }
}

// Application Insights (optional)
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = if enableApplicationInsights {
  name: applicationInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
  }
}

// App Service
resource appService 'Microsoft.Web/sites@2023-01-01' = {
  name: appServiceName
  location: location
  kind: 'app,linux,container'
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'DOCKER|${dockerImage}'
      alwaysOn: true
      http20Enabled: true
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      appSettings: [
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: dockerRegistryUrl
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_USERNAME'
          value: dockerRegistryUsername
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: enableApplicationInsights ? applicationInsights.properties.InstrumentationKey : ''
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: enableApplicationInsights ? applicationInsights.properties.ConnectionString : ''
        }
        // Environment variables should be added via Azure Portal or Azure CLI
        // Secrets should be stored in Azure Key Vault and referenced
      ]
    }
    httpsOnly: true
  }
}

// Outputs
output appServiceName string = appService.name
output appServiceUrl string = 'https://${appService.properties.defaultHostName}'
output applicationInsightsInstrumentationKey string = enableApplicationInsights ? applicationInsights.properties.InstrumentationKey : ''

