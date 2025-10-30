# Queue-Based Batch Translation System

## 🎯 Overview

The batch translation system now supports **asynchronous queue-based processing** for better scalability and reliability. This implementation uses Azure Queue Storage for job queuing and provides real-time progress tracking.

## 🏗️ Architecture

### Components

1. **Job Queue** (`QueueService`)
   - Azure Queue Storage: `translation-jobs`
   - Stores translation tasks for background processing
   - Supports both connection string and managed identity auth

2. **Job Tracker** (`TableJobTracker`)
   - Azure Table Storage for shared job status tracking
   - Tracks progress, completion, and errors across processes
   - Persistent storage survives restarts
   - Supports multiple worker/API instances

3. **Background Worker** (`worker.py`)
   - Continuously polls queue for new jobs
   - Processes translations asynchronously
   - Updates job status in real-time

4. **API Endpoints**
   - `POST /batch/jobs` - Start new batch job (returns immediately)
   - `GET /batch/jobs/{job_id}` - Poll job status
   - `GET /batch/jobs` - List all jobs

5. **Frontend Polling**
   - Auto-polls job status every 3 seconds
   - Updates progress bar in real-time
   - Stops polling when job completes

## 🔄 Processing Flow

### Synchronous Mode (Default: DISABLED)
```
User → API → Process ALL Files → Wait... → Return Complete
```

### Asynchronous Mode (Default: ENABLED)
```
User → API → Queue Files → Return Job ID (instant)
                              ↓
Background Worker → Process Files → Update Status
                              ↓
Frontend Polls Status → Update UI
```

## ⚙️ Configuration

### Enable/Disable Queue Mode

Set in `.env` or environment variables:
```bash
# Enable queue-based processing (default: true)
ENABLE_BATCH_QUEUE=true

# Disable for synchronous processing (testing only)
ENABLE_BATCH_QUEUE=false
```

### Azure Storage Requirements

**Required Services:**
- **Queue Storage**: `translation-jobs` queue for job messages
- **Table Storage**: `translationjobs` table for job tracking
- **Blob Storage**: Containers for source/target files

**Required Azure AD Roles** (if using managed identity):
- `Storage Blob Data Contributor` - Read/write batch files
- `Storage Queue Data Contributor` - Send/receive queue messages
- `Storage Table Data Contributor` - Track job status

**Settings:**
- **Queue Name**: `translation-jobs`
- **Table Name**: `translationjobs`
- **Visibility Timeout**: 300 seconds (5 minutes)
- **Max Messages per Poll**: 10
- **Worker Poll Interval**: 2 seconds

## 🚀 Running the System

### 1. Local Development (Docker)

**Option A: Backend + Worker in Docker**
```bash
# Start services
docker-compose up -d

# Backend runs on http://localhost:8000
# Worker runs automatically in background
```

**Option B: Backend Local + Worker Separate**
```bash
# Terminal 1: Start backend
cd src/backend
source ../../venv/bin/activate
export $(grep -v '^#' ../../.env | xargs)
uvicorn app.main:app --reload --port 8000

# Terminal 2: Start worker
cd src/backend
source ../../venv/bin/activate
export $(grep -v '^#' ../../.env | xargs)
python -m app.worker
```

### 2. Azure Deployment

The `deploy.sh` script automatically configures queue mode:
```bash
# Deploy infrastructure + application
bash infra/scripts/bootstrap.sh dev <PREFIX> --yes
bash infra/scripts/deploy.sh dev <PREFIX>
```

**Worker Deployment Options:**

1. **Azure Container Apps Jobs** (Recommended)
   - Scheduled or event-driven worker execution
   - Auto-scaling based on queue length
   
2. **Azure Functions (Queue Trigger)**
   - Serverless worker
   - Scales automatically with queue depth
   
3. **App Service (Background Task)**
   - Run worker alongside API
   - Use separate App Service for isolation

## 📊 Job Status

### Status Values

| Status | Description | Frontend Action |
|--------|-------------|-----------------|
| `queued` | Job created, files queued | Show progress bar, poll status |
| `processing` | Worker processing files | Update progress bar, continue polling |
| `completed` | All files processed successfully | Stop polling, show success message |
| `failed` | Job encountered fatal error | Stop polling, show error message |

### Status Response

```json
{
  "job_id": "abc-123",
  "status": "processing",
  "total_files": 10,
  "processed_files": 7,
  "failed_files": 1,
  "source_container": "exports",
  "target_container": "translations",
  "target_language": "es",
  "created_at": "2025-10-18T12:00:00Z",
  "updated_at": "2025-10-18T12:05:00Z",
  "completed_at": null
}
```

## 🧪 Testing

### Test Queue Mode

```bash
# 1. Ensure queue mode is enabled
export ENABLE_BATCH_QUEUE=true

# 2. Start backend + worker
docker-compose up -d

# 3. Upload sample files
python data/ingestion/upload_samples.py

# 4. Start batch job via API
curl -X POST http://localhost:8000/api/v1/batch/jobs \
  -H "Content-Type: application/json" \
  -d '{
    "source_container": "exports",
    "target_container": "translations",
    "target_language": "es"
  }'

# Response (instant):
{
  "job_id": "abc-123",
  "status": "queued",
  "total_files": 5,
  ...
}

# 5. Poll job status
curl http://localhost:8000/api/v1/batch/jobs/abc-123

# 6. Check worker logs
docker logs azure-translator-accelerator-backend-1 | grep "Worker"
```

### Test Synchronous Mode

```bash
# 1. Disable queue mode
export ENABLE_BATCH_QUEUE=false

# 2. Restart backend
docker-compose restart backend

# 3. Start batch job (will wait for completion)
curl -X POST http://localhost:8000/api/v1/batch/jobs \
  -H "Content-Type: application/json" \
  -d '{
    "source_container": "exports",
    "target_container": "translations",
    "target_language": "es"
  }'

# Response (after all files processed):
{
  "job_id": "abc-123",
  "status": "completed",
  "total_files": 5,
  "processed_files": 5,
  ...
}
```

## 📈 Monitoring

### Backend Logs

```bash
# Docker
docker logs -f azure-translator-accelerator-backend-1

# Local
tail -f logs/backend.log
```

**Key log messages:**
- `"Batch job {job_id} started: Queuing {N} files"` - Job started
- `"Processing job {job_id}: {filename}"` - Worker processing file
- `"Job completed: {job_id} ({M}/{N} succeeded)"` - Job finished
- `"Job {job_id}: {M}/{N} processed"` - Progress update

### Queue Monitoring

```python
# Check queue length
from app.services.queue_service import QueueService

queue = QueueService()
length = queue.get_queue_length()
print(f"Pending jobs: {length}")
```

### Job Tracker Inspection

```python
# List all jobs from Table Storage
from app.services.table_job_tracker import get_job_tracker

tracker = get_job_tracker()
jobs = tracker.get_all_jobs(limit=10)
for job in jobs:
    print(f"{job['job_id']}: {job['status']} ({job['processed_files']}/{job['total_files']})")
```

## 🔧 Troubleshooting

### Issue: Jobs stuck in "queued" status

**Cause**: Worker not running or crashed

**Solution**:
```bash
# Check worker status
docker logs azure-translator-accelerator-backend-1 | grep "Worker"

# Restart worker
docker-compose restart backend

# Or start worker manually
python -m app.worker
```

### Issue: Frontend not updating progress

**Cause**: Polling not working or CORS issue

**Solution**:
```bash
# Check browser console for errors
# Verify API endpoint accessible:
curl http://localhost:8000/api/v1/batch/jobs/{job_id}

# Check CORS settings in backend config
```

### Issue: Jobs processing slowly

**Cause**: Single worker, sequential processing

**Solution**:
```bash
# Option 1: Increase max_messages in worker
# Edit worker.py:
messages = self.queue_service.receive_messages(
    max_messages=20,  # Increase from 10
    visibility_timeout=300
)

# Option 2: Run multiple worker instances
python -m app.worker &  # Worker 1
python -m app.worker &  # Worker 2
python -m app.worker &  # Worker 3
```

### Issue: Queue authentication failed

**Cause**: Missing connection string or managed identity not configured

**Solution**:
```bash
# Local: Use connection string
export AZURE_STORAGE_CONNECTION_STRING="DefaultEndpointsProtocol=https;..."

# Azure: Enable managed identity and grant required roles
az webapp identity assign --name $BACKEND_APP_NAME --resource-group $RESOURCE_GROUP_NAME

# Grant all required storage roles
BACKEND_IDENTITY=$(az webapp identity show --name $BACKEND_APP_NAME --resource-group $RESOURCE_GROUP_NAME --query principalId -o tsv)
STORAGE_ID=$(az storage account show --name $STORAGE_NAME --resource-group $RESOURCE_GROUP_NAME --query id -o tsv)

az role assignment create --assignee $BACKEND_IDENTITY --role "Storage Blob Data Contributor" --scope $STORAGE_ID
az role assignment create --assignee $BACKEND_IDENTITY --role "Storage Queue Data Contributor" --scope $STORAGE_ID
az role assignment create --assignee $BACKEND_IDENTITY --role "Storage Table Data Contributor" --scope $STORAGE_ID
```

## 🚀 Production Recommendations

### 1. Job Tracking (Already Implemented)
✅ **Azure Table Storage** is production-ready:
- Shared state across all processes
- Persistent, durable storage
- Auto-scaling and high availability
- No additional infrastructure needed
- Cleanup old jobs automatically

**Alternative**: Redis for faster performance (if needed):
```python
class RedisJobTracker(JobTracker):
    def __init__(self, redis_url: str):
        import redis
        self.redis = redis.from_url(redis_url)
```

### 2. Deploy Dedicated Worker Service
- Use Azure Container Apps Jobs
- Configure auto-scaling based on queue depth:
  ```yaml
  scale:
    minReplicas: 1
    maxReplicas: 10
    rules:
    - name: queue-length
      type: azure-queue
      metadata:
        queueName: translation-jobs
        queueLength: '5'
  ```

### 3. Add Dead Letter Queue
Handle failed messages:
```python
# In QueueService
def move_to_dead_letter(self, message_id, error):
    dlq = self.queue_service_client.get_queue_client("translation-jobs-dlq")
    dlq.send_message(json.dumps({
        'original_message_id': message_id,
        'error': str(error),
        'timestamp': datetime.utcnow().isoformat()
    }))
```

### 4. Add Metrics & Alerts
```python
# Track metrics in Application Insights
from app.services.telemetry_service import track_metric

track_metric("batch_job_duration", duration_seconds)
track_metric("queue_depth", queue_length)
track_metric("processing_rate", files_per_second)
```

## 📚 Related Files

- **Backend**:
  - `src/backend/app/services/batch_service.py` - Batch processing logic
  - `src/backend/app/services/queue_service.py` - Azure Queue wrapper
  - `src/backend/app/services/table_job_tracker.py` - Azure Table Storage job tracking
  - `src/backend/app/worker.py` - Background worker
  - `src/backend/app/api/routes.py` - API endpoints

- **Frontend**:
  - `src/frontend/src/components/BatchTranslation.tsx` - UI with polling
  - `src/frontend/src/services/api.ts` - API client

- **Config**:
  - `src/backend/app/config.py` - `enable_batch_queue` flag
  - `.env` - `ENABLE_BATCH_QUEUE=true`
  - `docker-compose.yml` - Worker configuration

---

**Status**: ✅ Fully Implemented (October 2025)
**Version**: 1.0.0

