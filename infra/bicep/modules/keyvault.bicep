// Azure Key Vault module

@description('Key Vault name')
@minLength(3)
@maxLength(24)
param name string

@description('Location for the resource')
param location string

@description('Resource tags')
param tags object = {}

@description('Enable Azure Virtual Machines to retrieve certificates')
param enabledForDeployment bool = true

@description('Enable Azure Resource Manager to retrieve secrets')
param enabledForTemplateDeployment bool = true

@description('Enable Azure Disk Encryption to retrieve secrets')
param enabledForDiskEncryption bool = false

@description('Azure AD tenant ID')
param tenantId string

@description('Enable RBAC authorization')
param enableRbacAuthorization bool = false

@description('Enable soft delete')
param enableSoftDelete bool = true

@description('Soft delete retention period in days')
@minValue(7)
@maxValue(90)
param softDeleteRetentionInDays int = 90

@description('Enable purge protection')
param enablePurgeProtection bool = false

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    tenantId: tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enabledForDeployment: enabledForDeployment
    enabledForDiskEncryption: enabledForDiskEncryption
    enabledForTemplateDeployment: enabledForTemplateDeployment
    enableRbacAuthorization: enableRbacAuthorization
    enableSoftDelete: enableSoftDelete
    softDeleteRetentionInDays: softDeleteRetentionInDays
    enablePurgeProtection: enablePurgeProtection ? true : null
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
      ipRules: []
      virtualNetworkRules: []
    }
    accessPolicies: []
  }
}

// Outputs
output id string = keyVault.id
output name string = keyVault.name
output uri string = keyVault.properties.vaultUri

