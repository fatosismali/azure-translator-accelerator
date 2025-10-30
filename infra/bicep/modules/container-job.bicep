@description('Name of the Container Apps Job')
param name string

@description('Location for the resources')
param location string = resourceGroup().location

@description('Tags for the resources')
param tags object = {}

@description('Container Apps Environment ID')
param environmentId string

@description('Container image')
param containerImage string

@description('Container registry server')
param containerRegistryServer string

@description('Enable managed identity')
param enableManagedIdentity bool = true

@description('Environment variables')
param environmentVariables array = []

@description('Trigger type (Schedule or Event)')
@allowed([
  'Schedule'
  'Event'
  'Manual'
])
param triggerType string = 'Event'

@description('Cron expression for scheduled jobs')
param cronExpression string = '*/5 * * * *' // Every 5 minutes

@description('Polling interval in seconds (for event-driven jobs)')
param pollingInterval int = 30

@description('Min executions (for event-driven scaling)')
param minExecutions int = 0

@description('Max executions (for event-driven scaling)')
param maxExecutions int = 10

@description('Azure Queue Storage connection string secret name')
param queueConnectionSecretName string = ''

@description('Queue name to monitor')
param queueName string = 'translation-jobs'

@description('Queue length threshold for scaling')
param queueLength int = 5

resource containerJob 'Microsoft.App/jobs@2023-05-01' = {
  name: name
  location: location
  tags: tags
  identity: enableManagedIdentity ? {
    type: 'SystemAssigned'
  } : null
  properties: {
    environmentId: environmentId
    configuration: {
      triggerType: triggerType
      replicaTimeout: 1800 // 30 minutes
      replicaRetryLimit: 3
      manualTriggerConfig: triggerType == 'Manual' ? {
        replicaCompletionCount: 1
        parallelism: 1
      } : null
      scheduleTriggerConfig: triggerType == 'Schedule' ? {
        cronExpression: cronExpression
        parallelism: 1
        replicaCompletionCount: 1
      } : null
      eventTriggerConfig: triggerType == 'Event' ? {
        replicaCompletionCount: 1
        parallelism: 1
        scale: {
          minExecutions: minExecutions
          maxExecutions: maxExecutions
          pollingInterval: pollingInterval
          rules: [
            {
              name: 'queue-scaling'
              type: 'azure-queue'
              metadata: {
                queueName: queueName
                queueLength: string(queueLength)
                connectionFromEnv: 'AZURE_STORAGE_CONNECTION_STRING'
              }
            }
          ]
        }
      } : null
      registries: [
        {
          server: containerRegistryServer
          identity: 'system'
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'worker'
          image: containerImage
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: environmentVariables
        }
      ]
    }
  }
}

output id string = containerJob.id
output name string = containerJob.name
output principalId string = enableManagedIdentity ? containerJob.identity.principalId : ''

