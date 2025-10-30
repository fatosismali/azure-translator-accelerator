# Container Apps Job Worker Deployment

## Overview

The batch translation worker runs as an **Azure Container Apps Job** with event-driven scaling based on Azure Queue Storage depth.

## Architecture

```
┌─────────────────┐      ┌──────────────────┐      ┌─────────────────────┐
│   Backend API   │ ───▶ │  Azure Queue     │ ───▶ │  Container Apps Job │
│  (App Service)  │      │  Storage         │      │     (Worker)        │
└─────────────────┘      └──────────────────┘      └─────────────────────┘
         │                                                     │
         │                                                     │
         ▼                                                     ▼
┌──────────────────────────────────────────────────────────────────────┐
│                    Azure Table Storage                               │
│                    (Shared Job Tracking)                             │
└──────────────────────────────────────────────────────────────────────┘
```

## Infrastructure Components

### 1. Container Registry (ACR)
- **Purpose**: Stores worker Docker images
- **SKU**: Basic (dev) / Standard (prod)
- **Authentication**: Managed Identity (AcrPull role)
- **Image**: `translator-worker:latest`

### 2. Container Apps Environment
- **Purpose**: Hosts Container Apps and Jobs
- **Logging**: Integrated with Log Analytics
- **Networking**: Public (can be private for production)

### 3. Container Apps Job
- **Name**: `{prefix}-{env}-worker-job`
- **Trigger**: Event-driven (Azure Queue)
- **Scaling**:
  - Min: 0 executions (scales to zero when idle)
  - Max: 10 executions (parallel processing)
  - Rule: Queue length > 5 messages
  - Polling: Every 30 seconds
- **Timeout**: 30 minutes per execution
- **Retries**: 3 attempts on failure

## Deployment Process

### Automated (Recommended)

```bash
# 1. Deploy infrastructure (includes worker job)
bash infra/scripts/bootstrap.sh dev <prefix> --yes

# 2. Deploy code (builds and pushes worker image)
bash infra/scripts/deploy.sh dev <prefix>
```

**What happens:**
1. `bootstrap.sh` creates: ACR, Container Environment, Worker Job
2. `deploy.sh` builds worker image and pushes to ACR
3. Worker Job auto-configured with environment variables and secrets
4. All RBAC permissions granted automatically

### Manual Deployment

If you need to redeploy just the worker:

```bash
# Set variables
RESOURCE_GROUP="<your-rg>"
CONTAINER_REGISTRY="<your-acr-name>"
WORKER_JOB="<your-worker-job-name>"

# Build and push image
cd src/backend
az acr login --name $CONTAINER_REGISTRY
az acr build \
  --registry $CONTAINER_REGISTRY \
  --image translator-worker:latest \
  --file Dockerfile.worker \
  .

# Update worker job (if needed)
az containerapp job update \
  --name $WORKER_JOB \
  --resource-group $RESOURCE_GROUP \
  --image $CONTAINER_REGISTRY.azurecr.io/translator-worker:latest
```

## Configuration

### Environment Variables

The worker receives these from the Container Apps Job configuration:

```bash
# Azure Translator
AZURE_TRANSLATOR_KEY         # From Key Vault secret
AZURE_TRANSLATOR_ENDPOINT    # From Key Vault secret
AZURE_TRANSLATOR_REGION      # From Key Vault secret

# Azure Storage (Managed Identity)
AZURE_STORAGE_ACCOUNT_NAME   # Storage account for queue/blob/table

# Key Vault
AZURE_KEY_VAULT_URL          # For additional secrets if needed

# Configuration
ENVIRONMENT                  # dev/prod
ENABLE_BATCH_QUEUE           # true (always true for worker)

# Monitoring
APPLICATIONINSIGHTS_CONNECTION_STRING  # App Insights integration
```

### Managed Identity Permissions

The worker's managed identity has these roles:

| Role | Purpose |
|------|---------|
| **Storage Blob Data Contributor** | Read source files, write translated files |
| **Storage Queue Data Contributor** | Read and delete queue messages |
| **Storage Table Data Contributor** | Update job status in Table Storage |
| **AcrPull** | Pull worker image from Container Registry |
| **Key Vault Secrets User** | Read secrets (translator keys, etc.) |

## Scaling Behavior

### Event-Driven Scaling

The worker automatically scales based on queue depth:

```
Queue Messages    Worker Instances
─────────────────────────────────
0                 0 (scaled to zero)
1-5               1
6-10              2
11-50             Up to 10 (max)
50+               10 (max, queued)
```

**Scaling Rules:**
- **Scale Out**: When queue length > 5 messages
- **Scale In**: When queue is empty (after processing)
- **Polling**: Checks queue every 30 seconds
- **Cooldown**: ~2 minutes before scaling to zero

### Cost Optimization

- **Pay per execution**: No cost when idle
- **Cold start**: ~5-10 seconds to start from zero
- **Warm instances**: Sub-second start for subsequent runs
- **Typical cost**: $0.000024 per vCPU-second + $0.0000048 per GiB-second

### Performance

- **Resources**: 0.5 vCPU, 1 GiB memory per instance
- **Throughput**: ~20-30 files/minute per instance (depends on file size)
- **Parallel**: Up to 10 instances = 200-300 files/minute max

## Monitoring

### View Job Executions

```bash
# List recent executions
az containerapp job execution list \
  --name $WORKER_JOB \
  --resource-group $RESOURCE_GROUP \
  --output table

# Get execution logs
az containerapp job logs show \
  --name $WORKER_JOB \
  --resource-group $RESOURCE_GROUP \
  --execution <execution-name>
```

### Application Insights

The worker logs to Application Insights:

```kusto
// Recent worker executions
traces
| where cloud_RoleName == "translator-worker"
| where timestamp > ago(1h)
| project timestamp, message, severityLevel
| order by timestamp desc

// Worker errors
exceptions
| where cloud_RoleName == "translator-worker"
| where timestamp > ago(24h)
| project timestamp, type, outerMessage, innermostMessage
| order by timestamp desc

// Job processing metrics
customMetrics
| where name startswith "batch_"
| summarize avg(value) by name, bin(timestamp, 5m)
| render timechart
```

### Queue Monitoring

```bash
# Check queue length
az storage queue show \
  --name translation-jobs \
  --account-name $STORAGE_ACCOUNT \
  --auth-mode login \
  --query "approximateMessageCount"

# Peek at messages (without removing)
az storage message peek \
  --queue-name translation-jobs \
  --account-name $STORAGE_ACCOUNT \
  --auth-mode login \
  --num-messages 5
```

## Troubleshooting

### Worker Not Processing Jobs

1. **Check worker job status:**
   ```bash
   az containerapp job show \
     --name $WORKER_JOB \
     --resource-group $RESOURCE_GROUP \
     --query "properties.configuration"
   ```

2. **Verify image exists:**
   ```bash
   az acr repository show \
     --name $CONTAINER_REGISTRY \
     --image translator-worker:latest
   ```

3. **Check execution history:**
   ```bash
   az containerapp job execution list \
     --name $WORKER_JOB \
     --resource-group $RESOURCE_GROUP \
     --output table
   ```

4. **View logs for failed execution:**
   ```bash
   az containerapp job logs show \
     --name $WORKER_JOB \
     --resource-group $RESOURCE_GROUP \
     --execution <failed-execution-name>
   ```

### Permission Errors

If you see "AuthorizationPermissionMismatch" or similar:

```bash
# Get worker's managed identity
WORKER_IDENTITY=$(az containerapp job show \
  --name $WORKER_JOB \
  --resource-group $RESOURCE_GROUP \
  --query "identity.principalId" -o tsv)

# Verify role assignments
az role assignment list \
  --assignee $WORKER_IDENTITY \
  --output table

# Re-assign missing roles
STORAGE_ID=$(az storage account show \
  --name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --query "id" -o tsv)

az role assignment create \
  --assignee $WORKER_IDENTITY \
  --role "Storage Queue Data Contributor" \
  --scope $STORAGE_ID
```

### Scaling Issues

If the worker isn't scaling:

1. **Check scaling rules:**
   ```bash
   az containerapp job show \
     --name $WORKER_JOB \
     --resource-group $RESOURCE_GROUP \
     --query "properties.configuration.eventTriggerConfig.scale"
   ```

2. **Verify queue connection:**
   - Ensure `AZURE_STORAGE_ACCOUNT_NAME` is set
   - Check Storage Queue Data Contributor role
   - Verify queue name matches: `translation-jobs`

3. **Test manual trigger:**
   ```bash
   az containerapp job start \
     --name $WORKER_JOB \
     --resource-group $RESOURCE_GROUP
   ```

### Build Failures

If `deploy.sh` fails during image build:

1. **Check Dockerfile.worker exists:**
   ```bash
   ls -la src/backend/Dockerfile.worker
   ```

2. **Test local build:**
   ```bash
   cd src/backend
   docker build -f Dockerfile.worker -t translator-worker:test .
   ```

3. **Check ACR permissions:**
   ```bash
   az acr login --name $CONTAINER_REGISTRY
   ```

## Updating the Worker

### Code Changes

After modifying worker code:

```bash
# Redeploy (will rebuild and push new image)
bash infra/scripts/deploy.sh dev <prefix>
```

The worker will automatically use the new image on the next execution.

### Configuration Changes

To update environment variables or scaling rules:

```bash
# Edit infra/bicep/main.bicep (workerJob module parameters)
# Then redeploy infrastructure
bash infra/scripts/bootstrap.sh dev <prefix> --yes
```

### Image Tag Strategy

Current: `latest` tag (simple, good for dev)

**Production recommendation**: Use versioned tags:

```bash
# Build with version tag
az acr build \
  --registry $CONTAINER_REGISTRY \
  --image translator-worker:v1.2.3 \
  .

# Update job to use specific version
az containerapp job update \
  --name $WORKER_JOB \
  --resource-group $RESOURCE_GROUP \
  --image $CONTAINER_REGISTRY.azurecr.io/translator-worker:v1.2.3
```

## Production Considerations

### High Availability

- Container Apps Jobs have built-in retry logic
- Failed messages return to queue after visibility timeout
- Consider adding dead-letter queue for persistent failures

### Security

- **Network**: Use VNet integration for private networking
- **Secrets**: All sensitive data in Key Vault, never in env vars
- **Registry**: Use private ACR endpoint
- **Managed Identity**: No connection strings in production

### Cost Optimization

1. **Right-size resources**: Monitor CPU/memory usage
2. **Adjust scaling**: Tune `queueLength` threshold (currently 5)
3. **Optimize code**: Batch API calls, cache translations
4. **Use burstable**: Consider B-series instances for cost savings

### Monitoring

1. **Set up alerts**:
   - Queue depth > 100 (backlog building)
   - Worker execution failures > 5% 
   - Job execution duration > 20 minutes
   - No executions in 30 minutes (stuck?)

2. **Add custom metrics**:
   ```python
   # In worker code
   from applicationinsights import TelemetryClient
   tc = TelemetryClient(instrumentation_key=os.getenv('APPINSIGHTS_INSTRUMENTATION_KEY'))
   tc.track_metric('files_per_minute', throughput)
   tc.flush()
   ```

## Related Documentation

- [QUEUE_IMPLEMENTATION.md](QUEUE_IMPLEMENTATION.md) - Queue-based batch system overview
- [README.md](README.md) - Main deployment guide
- [Azure Container Apps Jobs Docs](https://learn.microsoft.com/en-us/azure/container-apps/jobs)

---

**Status**: ✅ Fully Implemented (October 2025)  
**Version**: 1.0.0

