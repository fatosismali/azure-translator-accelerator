// Main Bicep template for Azure Translator Solution Accelerator
// Orchestrates all infrastructure components

targetScope = 'resourceGroup'

// Parameters
@description('Environment name (dev, prod)')
@allowed(['dev', 'prod'])
param environment string = 'dev'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Resource prefix for naming')
@minLength(3)
@maxLength(10)
param resourcePrefix string = 'translator'

@description('Unique suffix for global resources (leave empty for auto-generation)')
param uniqueSuffix string = uniqueString(resourceGroup().id)

@description('Translator API tier')
@allowed(['F0', 'S1'])
param translatorSku string = environment == 'dev' ? 'F0' : 'S1'

@description('App Service Plan SKU')
param appServiceSku object = environment == 'dev' ? {
  name: 'F1'
  tier: 'Free'
  capacity: 1
} : {
  name: 'P1v3'
  tier: 'PremiumV3'
  capacity: 2
}

@description('Storage account replication type')
@allowed(['Standard_LRS', 'Standard_GRS', 'Standard_RAGRS'])
param storageReplication string = environment == 'dev' ? 'Standard_LRS' : 'Standard_GRS'

@description('Tags to apply to all resources')
param tags object = {
  Environment: environment
  Project: 'Azure-Translator-Accelerator'
  ManagedBy: 'Bicep'
}

// Variables
var resourceNamePrefix = '${resourcePrefix}-${environment}'
var translatorName = '${resourceNamePrefix}-translator-${uniqueSuffix}'
var aiFoundryName = '${resourceNamePrefix}-foundry-${uniqueSuffix}'
var keyVaultName = take('${resourceNamePrefix}-kv-${uniqueSuffix}', 24)
var appServicePlanName = '${resourceNamePrefix}-asp'
var backendAppName = '${resourceNamePrefix}-api-${uniqueSuffix}'
var frontendAppName = '${resourceNamePrefix}-web-${uniqueSuffix}'
var storageName = take(replace('${resourcePrefix}${environment}st${uniqueSuffix}', '-', ''), 24)
var appInsightsName = '${resourceNamePrefix}-ai'
var logAnalyticsName = '${resourceNamePrefix}-logs'

// Module: Azure Translator
module translator 'modules/translator.bicep' = {
  name: 'translator-deployment'
  params: {
    name: translatorName
    location: location
    sku: translatorSku
    tags: tags
  }
}

// Module: Azure AI Foundry (for LLM translation)
// Note: Deployed in Sweden Central due to GPT-4o-mini model availability
module aiFoundry 'modules/ai-foundry.bicep' = {
  name: 'ai-foundry-deployment'
  params: {
    aiFoundryName: aiFoundryName
    location: 'swedencentral'  // GPT-4o-mini requires specific regions
    tags: union(tags, {
      Note: 'Deployed in Sweden Central for GPT-4o-mini availability'
    })
    sku: environment == 'dev' ? 'S0' : 'S0'
    deployGpt4oMini: true
    gpt4oMiniCapacity: environment == 'dev' ? 10 : 50
  }
}

// Module: Key Vault
module keyVault 'modules/keyvault.bicep' = {
  name: 'keyvault-deployment'
  params: {
    name: keyVaultName
    location: location
    tags: tags
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enableRbacAuthorization: false
    tenantId: subscription().tenantId
  }
}

// Module: Storage Account
module storage 'modules/storage.bicep' = {
  name: 'storage-deployment'
  params: {
    name: storageName
    location: location
    skuName: storageReplication
    tags: tags
    containers: [
      'translations'
      'cache'
      'exports'
    ]
  }
}

// Module: Monitoring (App Insights + Log Analytics)
module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring-deployment'
  params: {
    appInsightsName: appInsightsName
    logAnalyticsName: logAnalyticsName
    location: location
    tags: tags
    retentionInDays: environment == 'dev' ? 30 : 90
  }
}

// Module: App Service (Backend API)
module appService 'modules/appservice.bicep' = {
  name: 'appservice-deployment'
  params: {
    appServicePlanName: appServicePlanName
    backendAppName: backendAppName
    frontendAppName: frontendAppName
    location: location
    sku: appServiceSku
    tags: tags
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
    appInsightsInstrumentationKey: monitoring.outputs.appInsightsInstrumentationKey
    keyVaultName: keyVault.outputs.name
    environment: environment
  }
}

// Store Translator credentials in Key Vault
resource translatorKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: '${keyVaultName}/translator-api-key'
  properties: {
    value: translator.outputs.primaryKey
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
  dependsOn: [
    keyVault
    translator
  ]
}

resource translatorRegionSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: '${keyVaultName}/translator-region'
  properties: {
    value: location
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
  dependsOn: [
    keyVault
  ]
}

resource translatorEndpointSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: '${keyVaultName}/translator-endpoint'
  properties: {
    value: translator.outputs.endpoint
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
  dependsOn: [
    keyVault
    translator
  ]
}

resource storageConnectionSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: '${keyVaultName}/storage-connection-string'
  properties: {
    value: storage.outputs.connectionString
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
  dependsOn: [
    keyVault
    storage
  ]
}

// Store AI Foundry credentials in Key Vault
resource aiFoundryEndpointSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: '${keyVaultName}/ai-foundry-endpoint'
  properties: {
    value: aiFoundry.outputs.aiFoundryEndpoint
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
  dependsOn: [
    keyVault
    aiFoundry
  ]
}

resource aiFoundryKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: '${keyVaultName}/ai-foundry-key'
  properties: {
    value: aiFoundry.outputs.aiFoundryPrimaryKey
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
  dependsOn: [
    keyVault
    aiFoundry
  ]
}

resource gpt4oMiniDeploymentNameSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: '${keyVaultName}/gpt4o-mini-deployment-name'
  properties: {
    value: aiFoundry.outputs.gpt4oMiniDeploymentName
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
  dependsOn: [
    keyVault
    aiFoundry
  ]
}

// Grant App Service Managed Identity access to Key Vault
resource keyVaultAccessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2023-07-01' = {
  name: '${keyVaultName}/add'
  properties: {
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: appService.outputs.backendIdentityPrincipalId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
    ]
  }
  dependsOn: [
    keyVault
    appService
  ]
}

// Grant App Service Managed Identity Storage Blob Data Contributor role
resource storageRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, backendAppName, 'StorageBlobDataContributor')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe') // Storage Blob Data Contributor
    principalId: appService.outputs.backendIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    storage
    appService
  ]
}

// Grant App Service Managed Identity Cognitive Services User role for AI Foundry
resource aiFoundryRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, backendAppName, 'CognitiveServicesUser')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a97b65f3-24c7-4388-baec-2e87135dc908') // Cognitive Services User
    principalId: appService.outputs.backendIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    aiFoundry
    appService
  ]
}

// Grant Translator resource access to AI Foundry (for LLM model access)
// Per https://learn.microsoft.com/en-us/azure/ai-services/translator/how-to/create-translator-resource?tabs=foundry
resource translatorToAiFoundryRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, translatorName, 'CognitiveServicesUser-AIFoundry')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a97b65f3-24c7-4388-baec-2e87135dc908') // Cognitive Services User
    principalId: translator.outputs.identityPrincipalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    translator
    aiFoundry
  ]
}

// Outputs
output resourceGroupName string = resourceGroup().name
output location string = location
output environment string = environment

// Translator outputs
output translatorName string = translator.outputs.name
output translatorEndpoint string = translator.outputs.endpoint
output translatorRegion string = location

// AI Foundry outputs
output aiFoundryName string = aiFoundry.outputs.aiFoundryName
output aiFoundryEndpoint string = aiFoundry.outputs.aiFoundryEndpoint
output gpt4oMiniDeploymentName string = aiFoundry.outputs.gpt4oMiniDeploymentName

// Key Vault outputs
output keyVaultName string = keyVault.outputs.name
output keyVaultUri string = keyVault.outputs.uri

// Storage outputs
output storageName string = storage.outputs.name
output storageAccountId string = storage.outputs.id

// App Service outputs
output backendAppName string = appService.outputs.backendAppName
output backendAppUrl string = appService.outputs.backendAppUrl
output frontendAppName string = appService.outputs.frontendAppName
output frontendAppUrl string = appService.outputs.frontendAppUrl
output appServicePlanName string = appService.outputs.appServicePlanName

// Monitoring outputs
output appInsightsName string = monitoring.outputs.appInsightsName
output appInsightsInstrumentationKey string = monitoring.outputs.appInsightsInstrumentationKey
output appInsightsConnectionString string = monitoring.outputs.appInsightsConnectionString
output logAnalyticsWorkspaceId string = monitoring.outputs.logAnalyticsWorkspaceId

// Deployment summary
output deploymentSummary object = {
  resourceGroup: resourceGroup().name
  environment: environment
  location: location
  backendUrl: appService.outputs.backendAppUrl
  frontendUrl: appService.outputs.frontendAppUrl
  apiDocsUrl: '${appService.outputs.backendAppUrl}/docs'
  appInsightsName: monitoring.outputs.appInsightsName
}

