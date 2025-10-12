// Production environment parameters
using '../main.bicep'

param environment = 'prod'
param resourcePrefix = 'translator'
param translatorSku = 'S1' // Standard tier
param storageReplication = 'Standard_GRS'
param appServiceSku = {
  name: 'P1v3'
  tier: 'PremiumV3'
  capacity: 2
}
param tags = {
  Environment: 'Production'
  Project: 'Azure-Translator-Accelerator'
  ManagedBy: 'Bicep'
  CostCenter: 'Engineering'
  Owner: 'PlatformTeam'
  Criticality: 'High'
}

