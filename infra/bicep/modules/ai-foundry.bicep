/*
  Azure AI Foundry (AI Services) with GPT-4o-mini deployment
  Provides LLM capabilities for advanced translation features
*/

@description('Name of the AI Foundry resource')
param aiFoundryName string

@description('Location for the AI Foundry resource')
param location string

@description('Tags for the resource')
param tags object = {}

@description('SKU for AI Foundry (S0 for standard)')
param sku string = 'S0'

@description('Deploy GPT-4o-mini model')
param deployGpt4oMini bool = true

@description('GPT-4o-mini deployment capacity (in thousands of tokens per minute)')
param gpt4oMiniCapacity int = 10

// Azure AI Services (AI Foundry) account
resource aiFoundry 'Microsoft.CognitiveServices/accounts@2023-10-01-preview' = {
  name: aiFoundryName
  location: location
  tags: tags
  kind: 'AIServices'
  sku: {
    name: sku
  }
  properties: {
    customSubDomainName: aiFoundryName
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
      ipRules: []
      virtualNetworkRules: []
    }
  }
}

// GPT-4o-mini deployment for LLM translation
resource gpt4oMiniDeployment 'Microsoft.CognitiveServices/accounts/deployments@2023-10-01-preview' = if (deployGpt4oMini) {
  parent: aiFoundry
  name: 'gpt-4o-mini'
  sku: {
    name: 'Standard'
    capacity: gpt4oMiniCapacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4o-mini'
      version: '2024-07-18'
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
    raiPolicyName: 'Microsoft.Default'
  }
}

// Outputs
output aiFoundryId string = aiFoundry.id
output aiFoundryName string = aiFoundry.name
output aiFoundryEndpoint string = aiFoundry.properties.endpoint
output aiFoundryPrimaryKey string = listKeys(aiFoundry.id, '2023-10-01-preview').key1
output gpt4oMiniDeploymentName string = deployGpt4oMini ? gpt4oMiniDeployment.name : ''

