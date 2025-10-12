// Azure Storage Account module

@description('Storage account name')
@minLength(3)
@maxLength(24)
param name string

@description('Location for the resource')
param location string

@description('Storage SKU')
@allowed(['Standard_LRS', 'Standard_GRS', 'Standard_RAGRS', 'Standard_ZRS', 'Premium_LRS'])
param skuName string = 'Standard_LRS'

@description('Resource tags')
param tags object = {}

@description('Blob containers to create')
param containers array = []

@description('Enable HTTPS only')
param httpsOnly bool = true

@description('Minimum TLS version')
@allowed(['TLS1_0', 'TLS1_1', 'TLS1_2'])
param minimumTlsVersion string = 'TLS1_2'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: skuName
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: httpsOnly
    minimumTlsVersion: minimumTlsVersion
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
      ipRules: []
      virtualNetworkRules: []
    }
    encryption: {
      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }
        file: {
          enabled: true
          keyType: 'Account'
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

// Blob service
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

// Create containers
resource blobContainers 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = [for container in containers: {
  parent: blobService
  name: container
  properties: {
    publicAccess: 'None'
  }
}]

// Table service
resource tableService 'Microsoft.Storage/storageAccounts/tableServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
}

// Create tables for translation history
resource translationHistoryTable 'Microsoft.Storage/storageAccounts/tableServices/tables@2023-01-01' = {
  parent: tableService
  name: 'TranslationHistory'
}

resource quotaTrackingTable 'Microsoft.Storage/storageAccounts/tableServices/tables@2023-01-01' = {
  parent: tableService
  name: 'QuotaTracking'
}

// Outputs
output id string = storageAccount.id
output name string = storageAccount.name
output primaryEndpoints object = storageAccount.properties.primaryEndpoints
output connectionString string = 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'

