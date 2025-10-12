// Development environment parameters
using '../main.bicep'

param environment = 'dev'
// resourcePrefix is set via command line --parameters
param translatorSku = 'S1' // Standard tier (changed from F0 due to free tier limit)
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

