// Azure Translator (Cognitive Services) module

@description('Translator resource name')
param name string

@description('Location for the resource')
param location string

@description('Translator SKU (F0 = Free, S1 = Standard)')
@allowed(['F0', 'S1', 'S2', 'S3', 'S4'])
param sku string = 'F0'

@description('Resource tags')
param tags object = {}

resource translator 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: name
  location: location
  tags: tags
  kind: 'TextTranslation'
  sku: {
    name: sku
  }
  properties: {
    customSubDomainName: name
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
      ipRules: []
      virtualNetworkRules: []
    }
    disableLocalAuth: false
    restore: false
    restrictOutboundNetworkAccess: false
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// Outputs
output id string = translator.id
output name string = translator.name
output endpoint string = translator.properties.endpoint
output primaryKey string = translator.listKeys().key1
output secondaryKey string = translator.listKeys().key2
output customDomain string = translator.properties.endpoint
output identityPrincipalId string = translator.identity.principalId

