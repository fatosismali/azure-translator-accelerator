# Azure Translator Solution Accelerator

A production-ready solution for deploying Azure Translator services with a modern web interface, batch processing capabilities, and dynamic dictionary support.

## ✨ Features

- **Multi-language Translation**: Support for 137+ languages with auto-detection
- **Batch Processing**: Async queue-based translation for multiple files
  - Real-time progress tracking
  - Background worker processing
  - Scalable architecture
- **Dynamic Dictionary**: Custom terminology and term preservation
- **Dual Translation Engine**: Compare Neural Machine Translation (NMT) vs LLM-based translation
- **Modern UI**: React-based frontend with dark mode support and real-time updates
- **RESTful API**: FastAPI backend with OpenAPI documentation
- **Azure Native**: Managed Identity, Key Vault integration, Application Insights

---

## 🚀 Quick Start

### Prerequisites

- Azure subscription
- Azure CLI installed and logged in (`az login`)
- Python 3.11+
- Node.js 18+ (for frontend)
- Git

### 1️⃣ Clone and Setup

```bash
git clone <your-repo-url>
cd azure-translator-accelerator

# Create Python virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install backend dependencies
pip install -r src/backend/requirements.txt
```

### 2️⃣ Deploy to Azure

```bash
# Deploy infrastructure and application
bash infra/scripts/bootstrap.sh dev <your-prefix> --yes
bash infra/scripts/deploy.sh dev <your-prefix> --yes

# Example:
bash infra/scripts/bootstrap.sh dev myapp --yes
bash infra/scripts/deploy.sh dev myapp --yes
```

**That's it!** Your application will be available at:
- Frontend: `https://<prefix>-dev-web-*.azurewebsites.net`
- Backend: `https://<prefix>-dev-api-*.azurewebsites.net`
- API Docs: `https://<prefix>-dev-api-*.azurewebsites.net/docs`

**Note on Batch Translation:**
- The backend supports **queue-based async processing** via Azure Queue Storage + Table Storage
- **Worker auto-deployed**: Azure Container Apps Job with event-driven scaling
  - Auto-scales from 0 to 10 based on queue depth
  - Polls queue every 30 seconds
  - Built and deployed automatically via `deploy.sh`
- Local testing: Run `python -m app.worker` in a separate terminal

---

## 🏠 Local Development

### Option 1: Quick Start (Recommended)

```bash
# 1. Setup environment
cp .env.example .env
# Edit .env with your Azure credentials

# 2. Start frontend (Docker)
docker-compose up -d frontend

# 3. Start backend + worker (local - avoids Conditional Access issues)

# Terminal 1: Backend API
cd src/backend
source ../../venv/bin/activate
export $(grep -v '^#' ../../.env | xargs)
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

# Terminal 2: Background Worker (for batch jobs)
# Run from project root
cd <project-root>
source venv/bin/activate
PYTHONPATH=$(pwd)/src/backend python -m app.worker
```

Access:
- Frontend: http://localhost:3000
- Backend API: http://localhost:8000
- API Docs: http://localhost:8000/docs

### Option 2: Full Docker

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f
```

**Note**: If your organization has Conditional Access policies, use Option 1 (local backend) as it uses your Azure CLI credentials which satisfy CA policies.

---

## 📋 Environment Configuration

### Required Variables (.env file)

```bash
# Azure Translator
AZURE_TRANSLATOR_KEY=<your-key>
AZURE_TRANSLATOR_REGION=<region>
AZURE_TRANSLATOR_ENDPOINT=https://api.cognitive.microsofttranslator.com

# Storage (for local development - requires Azure AD roles)
AZURE_STORAGE_ACCOUNT_NAME=<storage-account-name>

# Batch Processing (queue-based)
ENABLE_BATCH_QUEUE=true

# Optional: AI Foundry (for LLM translation)
AZURE_AI_FOUNDRY_ENDPOINT=<endpoint>
AZURE_AI_FOUNDRY_KEY=<key>
```

Get these values after running `deploy.sh` - they're automatically saved to `.env`.

**Required Azure AD Roles** (for local development):
- `Storage Blob Data Contributor` - Read/write batch files
- `Storage Queue Data Contributor` - Access job queue
- `Storage Table Data Contributor` - Track job status

Assign to your Azure account:
```bash
STORAGE_NAME="<your-storage-account>"
STORAGE_ID=$(az storage account show --name $STORAGE_NAME --resource-group <rg> --query id -o tsv)
USER_EMAIL="<your-email@domain.com>"

az role assignment create --assignee $USER_EMAIL --role "Storage Blob Data Contributor" --scope $STORAGE_ID
az role assignment create --assignee $USER_EMAIL --role "Storage Queue Data Contributor" --scope $STORAGE_ID
az role assignment create --assignee $USER_EMAIL --role "Storage Table Data Contributor" --scope $STORAGE_ID
```

---

## 🧪 Testing

### Upload Sample Files

```bash
# Load sample translation files to Azure Storage
cd src/backend
source ../../venv/bin/activate
cd ../../

python3 << 'EOF'
import json
from pathlib import Path
from azure.storage.blob import BlobServiceClient
from azure.identity import DefaultAzureCredential

# Use your storage account name
account_name = "<your-storage-account-name>"
credential = DefaultAzureCredential()
blob_service_client = BlobServiceClient(
    account_url=f"https://{account_name}.blob.core.windows.net",
    credential=credential
)

# Upload samples
samples_file = Path("data/samples/sample_texts.json")
with open(samples_file, 'r') as f:
    samples = json.load(f)

container_client = blob_service_client.get_container_client("translations")

for sample in samples:
    blob_name = f"sample_{sample['id']:03d}_{sample['language']}.txt"
    blob_client = container_client.get_blob_client(blob_name)
    blob_client.upload_blob(sample['text'], overwrite=True)
    print(f"✓ Uploaded: {blob_name}")

print(f"✓ Uploaded {len(samples)} sample files")
EOF
```

### Test Batch Translation

1. Open the frontend (local or Azure)
2. Go to **Batch** tab
3. Configure:
   - Source Container: `translations`
   - Target Container: `exports`
   - Target Language: Any (e.g., French, Spanish)
   - Source Language: Auto-detect
4. (Optional) Add dictionary terms to preserve technical words
5. Click **Start Batch Translation**

---

## 🔧 Troubleshooting

### Local Development

**Port 8000 already in use:**
```bash
# Stop any Docker containers
docker-compose stop backend
docker-compose rm -f backend

# Kill process on port 8000
lsof -ti:8000 | xargs kill -9
```

**Storage authentication fails:**
```bash
# Ensure you're logged in
az login

# Verify your account has Storage Blob Data Contributor role
az role assignment list --assignee $(az account show --query user.name -o tsv) --all
```

**Missing Python packages:**
```bash
pip install -r src/backend/requirements.txt
```

### Azure Deployment

**502 Bad Gateway after deployment:**
- Wait 2-3 minutes for the app to fully start
- Check logs: `az webapp log tail --name <app-name> --resource-group <resource-group>`

**Key Vault access errors:**
```bash
# Temporarily enable public access for deployment
az keyvault update --name <keyvault-name> --resource-group <resource-group> --public-network-access Enabled

# Run deployment
bash infra/scripts/deploy.sh dev <prefix> --yes

# Disable public access again
az keyvault update --name <keyvault-name> --resource-group <resource-group> --public-network-access Disabled
```

**Deployment times out:**
- The backend deployment can take 3-4 minutes due to Oryx build
- This is normal - wait for it to complete

---

## 📚 Architecture

### Components

```
┌─────────────────┐     ┌─────────────────┐
│   React         │────▶│   FastAPI       │
│   Frontend      │     │   Backend       │
│   (Port 3000)   │     │   (Port 8000)   │
└─────────────────┘     └─────────────────┘
                               │
                ┌──────────────┼──────────────┐
                │              │              │
         ┌──────▼─────┐ ┌─────▼──────┐ ┌────▼────┐
         │  Azure     │ │   Azure    │ │  Azure  │
         │ Translator │ │   Blob     │ │   AI    │
         │  Service   │ │  Storage   │ │ Foundry │
         └────────────┘ └────────────┘ └─────────┘
```

### Authentication

| Environment | Method | Notes |
|-------------|--------|-------|
| **Local** | Azure CLI (`az login`) | Uses your personal credentials |
| **Azure** | Managed Identity | No secrets in code |
| **Docker (local)** | Service Principal | If CA policies allow |

---

## 🎯 Key Features Guide

### Dynamic Dictionary

Preserve technical terms or provide custom translations:

```json
{
  "Azure": "Azure",           // Preserve as-is
  "API": "API",               // Preserve as-is
  "service": "servicio"       // Custom translation
}
```

The solution automatically wraps terms with `<mstrans:dictionary>` tags for Azure Translator.

### Batch Translation

1. Upload text files to a source container
2. Configure source/target containers and language
3. Run batch job
4. Results saved to target container with both NMT and LLM translations

### Translation Comparison

Compare two translation methods:
- **NMT**: Azure Translator Neural Machine Translation
- **LLM**: GPT-4o-mini based translation (requires AI Foundry)

---

## 🔐 Security

- **Key Vault**: All secrets stored in Azure Key Vault
- **Managed Identity**: No credentials in code or config
- **Private Endpoints**: Recommended for production (configure via Bicep)
- **RBAC**: Least privilege access with Azure AD roles

---

## 📦 Project Structure

```
azure-translator-accelerator/
├── src/
│   ├── backend/           # FastAPI backend
│   │   ├── app/
│   │   │   ├── api/       # API routes and models
│   │   │   ├── services/  # Business logic
│   │   │   └── main.py    # Application entry
│   │   └── requirements.txt
│   └── frontend/          # React frontend
│       ├── src/
│       │   ├── components/
│       │   └── services/
│       └── package.json
├── infra/
│   ├── bicep/             # Infrastructure as Code
│   │   ├── main.bicep
│   │   └── modules/
│   └── scripts/
│       ├── bootstrap.sh   # Deploy infrastructure
│       └── deploy.sh      # Deploy application
├── data/
│   └── samples/           # Sample translation files
├── docker-compose.yml
└── README.md
```

---

## 🔄 Development Workflow

### Make Changes Locally

1. Edit code in `src/backend/` or `src/frontend/`
2. Backend auto-reloads with `uvicorn --reload`
3. Frontend auto-reloads with Vite dev server
4. Test at http://localhost:3000

### Deploy Changes to Azure

```bash
# Deploy updated code (infrastructure unchanged)
bash infra/scripts/deploy.sh dev <prefix> --yes

# View deployment logs
az webapp log tail --name <prefix>-dev-api-* --resource-group <prefix>-dev-rg
```

### Update Infrastructure

```bash
# Modify files in infra/bicep/
# Then redeploy
bash infra/scripts/bootstrap.sh dev <prefix> --yes
```

---

## 📊 Monitoring

View logs in Azure:
```bash
# Backend logs
az webapp log tail --name <prefix>-dev-api-* --resource-group <prefix>-dev-rg

# Frontend logs
az webapp log tail --name <prefix>-dev-web-* --resource-group <prefix>-dev-rg
```

Application Insights is automatically configured for monitoring and diagnostics.

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🆘 Support

- **Issues**: Open an issue on GitHub
- **Documentation**: Check inline code comments and API docs at `/docs` endpoint
- **Azure Docs**: https://learn.microsoft.com/azure/ai-services/translator/

---

## ⚡ Quick Command Reference

```bash
# Deploy everything to Azure
bash infra/scripts/bootstrap.sh dev myapp --yes
bash infra/scripts/deploy.sh dev myapp --yes

# Run locally
docker-compose up -d frontend
cd src/backend && uvicorn app.main:app --reload

# View logs
docker-compose logs -f
az webapp log tail --name <app-name> --resource-group <rg>

# Cleanup
az group delete --name <prefix>-dev-rg --yes
```

---

**Built with ❤️ using Azure AI Services**
