@description('Name of the Container Apps Environment')
param name string

@description('Location for the resources')
param location string = resourceGroup().location

@description('Tags for the resources')
param tags object = {}

@description('Log Analytics Workspace ID')
param logAnalyticsWorkspaceId string

resource containerEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: reference(logAnalyticsWorkspaceId, '2021-06-01').customerId
        sharedKey: listKeys(logAnalyticsWorkspaceId, '2021-06-01').primarySharedKey
      }
    }
    zoneRedundant: false
  }
}

output id string = containerEnvironment.id
output name string = containerEnvironment.name
output defaultDomain string = containerEnvironment.properties.defaultDomain

