// Development environment parameters
using '../main.bicep'

param environment = 'dev'
param resourcePrefix = 'translator'
param translatorSku = 'F0' // Free tier
param storageReplication = 'Standard_LRS'
param appServiceSku = {
  name: 'F1'
  tier: 'Free'
  capacity: 1
}
param tags = {
  Environment: 'Development'
  Project: 'Azure-Translator-Accelerator'
  ManagedBy: 'Bicep'
  CostCenter: 'Engineering'
  Owner: 'DevTeam'
}

