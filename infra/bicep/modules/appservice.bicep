// App Service module (Backend API + Frontend Web App)

@description('App Service Plan name')
param appServicePlanName string

@description('Backend App Service name')
param backendAppName string

@description('Frontend App Service name')
param frontendAppName string

@description('Location for the resources')
param location string

@description('App Service Plan SKU')
param sku object

@description('Resource tags')
param tags object = {}

@description('Application Insights connection string')
param appInsightsConnectionString string

@description('Application Insights instrumentation key')
param appInsightsInstrumentationKey string

@description('Key Vault name for secret references')
param keyVaultName string

@description('Environment (dev, prod)')
param environment string

// App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: appServicePlanName
  location: location
  tags: tags
  sku: {
    name: sku.name
    tier: sku.tier
    capacity: sku.capacity
  }
  kind: 'linux'
  properties: {
    reserved: true // Required for Linux
    zoneRedundant: false
  }
}

// Backend API App Service
resource backendApp 'Microsoft.Web/sites@2023-01-01' = {
  name: backendAppName
  location: location
  tags: union(tags, { Role: 'Backend-API' })
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    clientAffinityEnabled: false
    siteConfig: {
      linuxFxVersion: 'PYTHON|3.11'
      alwaysOn: sku.tier != 'Free' && sku.tier != 'Shared'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      http20Enabled: true
      healthCheckPath: '/health'
      cors: {
        allowedOrigins: [
          'https://${frontendAppName}.azurewebsites.net'
          'http://localhost:3000'
          'http://localhost:5173'
        ]
        supportCredentials: false
      }
      appSettings: [
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsightsInstrumentationKey
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'AZURE_TRANSLATOR_KEY'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=translator-api-key)'
        }
        {
          name: 'AZURE_TRANSLATOR_REGION'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=translator-region)'
        }
        {
          name: 'AZURE_TRANSLATOR_ENDPOINT'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=translator-endpoint)'
        }
        {
          name: 'AZURE_AI_FOUNDRY_ENDPOINT'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=ai-foundry-endpoint)'
        }
        {
          name: 'AZURE_AI_FOUNDRY_KEY'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=ai-foundry-key)'
        }
        {
          name: 'GPT4O_MINI_DEPLOYMENT_NAME'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=gpt4o-mini-deployment-name)'
        }
        {
          name: 'AZURE_STORAGE_CONNECTION_STRING'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=storage-connection-string)'
        }
        {
          name: 'AZURE_KEY_VAULT_URL'
          value: 'https://${keyVaultName}.vault.azure.net/'
        }
        {
          name: 'ENVIRONMENT'
          value: environment
        }
        {
          name: 'APP_NAME'
          value: 'translator-accelerator'
        }
        {
          name: 'LOG_LEVEL'
          value: environment == 'dev' ? 'DEBUG' : 'INFO'
        }
        {
          name: 'ENABLE_TELEMETRY'
          value: 'true'
        }
        {
          name: 'ENABLE_CACHING'
          value: 'false'
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '0'
        }
      ]
    }
  }
}

// Backend App Service - Staging Slot (for prod)
resource backendStagingSlot 'Microsoft.Web/sites/slots@2023-01-01' = if (environment == 'prod') {
  parent: backendApp
  name: 'staging'
  location: location
  tags: union(tags, { Role: 'Backend-API-Staging' })
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    clientAffinityEnabled: false
    siteConfig: {
      linuxFxVersion: 'PYTHON|3.11'
      alwaysOn: true
    }
  }
}

// Frontend Web App Service
resource frontendApp 'Microsoft.Web/sites@2023-01-01' = {
  name: frontendAppName
  location: location
  tags: union(tags, { Role: 'Frontend-Web' })
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    clientAffinityEnabled: false
    siteConfig: {
      linuxFxVersion: 'NODE|20-lts'
      alwaysOn: sku.tier != 'Free' && sku.tier != 'Shared'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      http20Enabled: true
      appSettings: [
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        {
          name: 'VITE_API_BASE_URL'
          value: 'https://${backendAppName}.azurewebsites.net'
        }
        {
          name: 'VITE_APPINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        {
          name: 'NODE_ENV'
          value: 'production'
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
      ]
    }
  }
}

// Outputs
output appServicePlanId string = appServicePlan.id
output appServicePlanName string = appServicePlan.name

output backendAppId string = backendApp.id
output backendAppName string = backendApp.name
output backendAppUrl string = 'https://${backendApp.properties.defaultHostName}'
output backendIdentityPrincipalId string = backendApp.identity.principalId

output frontendAppId string = frontendApp.id
output frontendAppName string = frontendApp.name
output frontendAppUrl string = 'https://${frontendApp.properties.defaultHostName}'
output frontendIdentityPrincipalId string = frontendApp.identity.principalId

output backendStagingSlotName string = environment == 'prod' ? backendStagingSlot.name : ''

