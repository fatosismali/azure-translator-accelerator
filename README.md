# Azure AI Translator Solution Accelerator

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A production-grade solution accelerator demonstrating end-to-end integration with Azure AI Translator Service, featuring both traditional Neural Machine Translation (NMT) and cutting-edge LLM-powered translation with GPT-4o/GPT-4o-mini.

## 🎯 What You'll Get

- **Complete Working Application**: Frontend + Backend + Infrastructure ready to deploy
- **Dual Translation Engines**: Compare NMT vs LLM translations side-by-side
- **Batch Processing**: Translate multiple files from Azure Storage
- **Dictionary & Examples**: Get alternative translations with real-world usage examples
- **Production-Ready**: Security, monitoring, and CI/CD pipelines included
- **Cost-Effective**: Free tier supported, ~$2.50/month for dev environment

## ✨ Key Features

| Feature | Description |
|---------|-------------|
| 🌍 **137 Languages** | Translate between 137+ languages using Azure Translator |
| 🤖 **LLM Translation** | GPT-4o/mini powered translation with tone & gender control |
| ⚖️ **Side-by-Side Compare** | Compare NMT vs LLM translations in real-time |
| 📖 **Dictionary Lookup** | Alternative translations with usage examples |
| 📦 **Batch Translation** | Process multiple .txt files from Azure Storage |
| 📊 **Translation Rating** | Evaluate and compare translation quality |
| 🔐 **Secure by Default** | Managed Identity, Key Vault, no secrets in code |
| 📈 **Built-in Monitoring** | Application Insights integration included |

---

## 📋 Prerequisites

Before you begin, ensure you have:

- **Azure Subscription** - [Create a free account](https://azure.microsoft.com/free/)
- **Azure CLI** - [Install guide](https://docs.microsoft.com/cli/azure/install-azure-cli) (v2.50+)
- **Python 3.9+** - [Download](https://www.python.org/downloads/)
- **Node.js 20+** - [Download](https://nodejs.org/)
- **Git** - [Download](https://git-scm.com/downloads)

> **Note**: Docker is NOT required. This guide covers native setup.

---

## 🚀 Setup Guide

### Option 1: Local Development (Test Without Azure Costs)

Perfect for trying out the application before deploying to Azure.

#### Step 1: Clone the Repository

```bash
git clone <your-repo-url>
cd AITranslatorAccelerator-Fatos
```

#### Step 2: Get Azure Translator Credentials

You need an Azure Translator resource (Free tier works!):

1. Go to [Azure Portal](https://portal.azure.com)
2. Click "Create a resource" → Search "Translator"
3. Click "Create" and fill in:
   - **Subscription**: Your Azure subscription
   - **Resource Group**: Create new (e.g., `translator-test-rg`)
   - **Region**: Choose closest to you (e.g., `UK South`)
   - **Name**: Choose a unique name (e.g., `my-translator-test`)
   - **Pricing Tier**: F0 (Free - 2M chars/month)
4. Click "Review + Create" → "Create"
5. Once deployed, go to resource → "Keys and Endpoint"
6. Copy **Key 1** and **Location/Region**

#### Step 3: Configure Environment Variables

Create a `.env` file in the project root:

```bash
# Copy the example file
cp env.example .env

# Edit .env with your credentials
# (Use nano, vim, or any text editor)
nano .env
```

**Required values in `.env`:**
```bash
AZURE_TRANSLATOR_KEY=<paste-your-key-1-here>
AZURE_TRANSLATOR_REGION=<paste-your-region-here>  # e.g., uksouth
AZURE_TRANSLATOR_ENDPOINT=https://api.cognitive.microsofttranslator.com

# For local testing without AI Foundry, you can comment out these:
# AZURE_AI_FOUNDRY_ENDPOINT=...
# AZURE_AI_FOUNDRY_KEY=...
# GPT4O_MINI_DEPLOYMENT_NAME=...
```

> **Note**: LLM translation features require Azure AI Foundry. For now, focus on NMT translation which works with just the Translator key.

#### Step 4: Install Backend Dependencies

```bash
cd src/backend

# Install Python dependencies
pip3 install -r requirements.txt

# Verify installation
python3 -c "import fastapi; print('✅ FastAPI installed')"
```

#### Step 5: Run the Backend

```bash
# From src/backend directory
python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

You should see:
```
INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
```

**Test it**: Open http://localhost:8000/docs in your browser - you should see the API documentation.

#### Step 6: Install Frontend Dependencies

Open a **new terminal window**:

```bash
cd src/frontend

# Install Node.js dependencies
npm install

# Verify installation
npm list react
```

#### Step 7: Configure Frontend for Local Backend

Create `.env.local` in `src/frontend`:

```bash
# In src/frontend directory
echo "VITE_API_BASE_URL=http://localhost:8000" > .env.local
```

#### Step 8: Run the Frontend

```bash
# From src/frontend directory
npm run dev
```

You should see:
```
  VITE v5.x.x  ready in xxx ms

  ➜  Local:   http://localhost:5173/
```

**Test it**: Open http://localhost:5173 in your browser.

#### Step 9: Test the Application

1. **Translate Tab**: Enter "Hello world", select Spanish, click Translate
2. **Dictionary Tab**: Enter "hello", select English → Spanish, click Look Up
3. **Compare Tab** (if AI Foundry configured): Compare NMT vs LLM translations

**🎉 Success!** Your local setup is complete.

---

### Option 2: Deploy to Azure (Production Setup)

Deploy the full application to Azure with all features enabled.

#### Step 1: Clone and Prepare

```bash
git clone <your-repo-url>
cd AITranslatorAccelerator-Fatos
```

#### Step 2: Login to Azure

```bash
az login

# If you have multiple subscriptions, set the one you want to use:
az account list --output table
az account set --subscription "<your-subscription-id>"
```

#### Step 3: Configure Deployment Parameters

Edit `infra/bicep/parameters/dev.bicepparam`:

```bicep
using '../main.bicep'

param environment = 'dev'
param location = 'uksouth'  // Change to your preferred region
param resourcePrefix = 'translator'  // Change if desired
// uniqueSuffix will be auto-generated
```

**Important Regions for LLM Translation:**
- GPT-4o-mini requires: `swedencentral`, `eastus2`, `westus`, `australiaeast`, etc.
- The template automatically deploys AI Foundry to `swedencentral`

#### Step 4: Deploy Infrastructure

```bash
# Navigate to infrastructure directory
cd infra/scripts

# Run deployment script (takes ~10-15 minutes)
bash bootstrap.sh dev uksouth

# Or for Windows PowerShell:
# .\bootstrap.ps1 -Environment dev -Location uksouth
```

This will create:
- ✅ Azure Translator (Free or S1 tier)
- ✅ Azure AI Foundry with GPT-4o-mini deployment
- ✅ Azure Storage Account (with containers)
- ✅ Azure Key Vault (for secrets)
- ✅ App Service Plan + 2 Web Apps (backend + frontend)
- ✅ Application Insights (monitoring)

**Expected output:**
```
✅ Infrastructure deployment completed successfully!

📝 Deployment Summary:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Resource Group: translator-dev-rg
Backend API:    https://translator-dev-api-xxx.azurewebsites.net
Frontend Web:   https://translator-dev-web-xxx.azurewebsites.net
```

**Copy these URLs** - you'll need them for the next steps!

#### Step 5: Deploy Backend Code

```bash
cd ../../src/backend

# Create deployment package
zip -r backend-deploy.zip . -x "*.pyc" -x "__pycache__/*" -x ".venv/*" -x "*.egg-info/*"

# Deploy to Azure (replace with your app name)
az webapp deploy \
  --resource-group translator-dev-rg \
  --name <your-backend-app-name> \
  --src-path backend-deploy.zip \
  --type zip
```

Wait for deployment (~2-3 minutes). Then test:

```bash
# Replace with your backend URL
curl https://<your-backend-api>.azurewebsites.net/api/v1/languages
```

You should see a JSON response with languages.

#### Step 6: Deploy Frontend Code

```bash
cd ../frontend

# Build with production API URL (replace with YOUR backend URL)
VITE_API_BASE_URL=https://<your-backend-api>.azurewebsites.net npm run build

# Deploy to Azure
cd dist
az webapp deploy \
  --resource-group translator-dev-rg \
  --name <your-frontend-app-name> \
  --src-path index.html \
  --type static \
  --target-path index.html

# Deploy assets
cd assets
for file in *.js; do
  az webapp deploy \
    --resource-group translator-dev-rg \
    --name <your-frontend-app-name> \
    --src-path "$file" \
    --type static \
    --target-path "assets/$file"
done
```

#### Step 7: Configure Storage Access (for Batch Features)

The batch translation feature needs storage permissions:

```bash
# Grant App Service access to Storage
az role assignment create \
  --assignee $(az webapp identity show \
    --resource-group translator-dev-rg \
    --name <your-backend-app-name> \
    --query principalId --output tsv) \
  --role "Storage Blob Data Contributor" \
  --scope $(az storage account show \
    --resource-group translator-dev-rg \
    --name <your-storage-account-name> \
    --query id --output tsv)

# Wait 2-5 minutes for permissions to propagate
```

#### Step 8: Test Your Deployment

1. Open your frontend URL in a browser
2. Try the **Translate** tab - translate some text
3. Try the **Compare** tab - see NMT vs LLM comparison
4. Try the **Dictionary** tab - lookup words
5. Try the **Batch** tab:
   - Upload some .txt files to your storage account first
   - Select source/target containers
   - Start batch translation

**🎉 Congratulations!** Your Azure deployment is complete.

---

## 📁 Repository Structure

```
.
├── infra/                      # Azure Infrastructure
│   ├── bicep/                  # Bicep templates
│   │   ├── main.bicep          # Main template
│   │   ├── modules/            # Resource modules
│   │   └── parameters/         # Environment configs
│   └── scripts/                # Deployment scripts
│       ├── bootstrap.sh        # Deploy infrastructure
│       └── cleanup.sh          # Destroy infrastructure
│
├── src/
│   ├── backend/                # Python FastAPI Backend
│   │   ├── app/
│   │   │   ├── api/            # API routes & models
│   │   │   ├── services/       # Business logic
│   │   │   ├── middleware/     # Logging, CORS
│   │   │   └── main.py         # App entry point
│   │   └── requirements.txt    # Python dependencies
│   │
│   └── frontend/               # React TypeScript Frontend
│       ├── src/
│       │   ├── components/     # UI components
│       │   ├── services/       # API client
│       │   └── types/          # TypeScript types
│       └── package.json        # Node dependencies
│
├── docs/                       # Documentation
│   ├── architecture.md         # Architecture details
│   ├── llm-translation.md      # LLM feature guide
│   └── troubleshooting.md      # Common issues
│
├── env.example                 # Environment template
├── test_azure_deployment.sh    # Deployment test script
└── README.md                   # This file
```

---

## 🔧 Configuration Reference

### Environment Variables

#### Backend (`.env` or App Service settings)

```bash
# Required - Azure Translator
AZURE_TRANSLATOR_KEY=<your-key>
AZURE_TRANSLATOR_REGION=<region>  # e.g., uksouth
AZURE_TRANSLATOR_ENDPOINT=https://api.cognitive.microsofttranslator.com

# Required for LLM Translation
AZURE_AI_FOUNDRY_ENDPOINT=<foundry-endpoint>
AZURE_AI_FOUNDRY_KEY=<foundry-key>
GPT4O_MINI_DEPLOYMENT_NAME=gpt-4o-mini

# Required for Batch Translation
AZURE_STORAGE_ACCOUNT_NAME=<storage-account-name>

# Optional - Monitoring
APPLICATIONINSIGHTS_CONNECTION_STRING=<connection-string>

# Optional - Security
AZURE_KEY_VAULT_URL=https://<vault-name>.vault.azure.net/
```

#### Frontend (`.env.local` or build-time)

```bash
# Backend API URL
VITE_API_BASE_URL=http://localhost:8000  # Local
# OR
VITE_API_BASE_URL=https://your-api.azurewebsites.net  # Azure
```

---

## 🧪 Testing Your Deployment

Use the included test script:

```bash
# Test all endpoints
bash test_azure_deployment.sh

# Or test manually:
# 1. Languages API
curl https://<your-backend>.azurewebsites.net/api/v1/languages

# 2. Translation API
curl -X POST https://<your-backend>.azurewebsites.net/api/v1/translate \
  -H "Content-Type: application/json" \
  -d '{"text":"Hello","from":"en","to":["es"]}'

# 3. Storage/Batch API (after RBAC propagates)
curl https://<your-backend>.azurewebsites.net/api/v1/batch/containers
```

---

## 🎨 Using the Application

### 1. Translate Tab
- Enter text in any language
- Select source language (or auto-detect)
- Select target language
- Click "Translate"

### 2. Compare Tab (NMT vs LLM)
- Enter text to compare
- Select source and target languages
- Choose LLM model (GPT-4o-mini or GPT-4o)
- Optionally set tone (formal/informal) and gender
- Click "Compare Translations"
- View side-by-side results

### 3. Dictionary Tab
- Enter a word or phrase
- Select language pair
- Click "Look Up" for alternatives
- Click "Examples" to see usage in context
- Use "Compare Mode" to see NMT vs LLM dictionary lookups

### 4. Batch Tab
- Upload .txt files to Azure Storage container (via Azure Portal)
- Select source container (with .txt files)
- Select target container (for translations)
- Choose source/target languages
- Click "Start Batch Translation"
- Files will be translated to both `nmt/` and `llm/` folders

### 5. Review Tab
- Select source and target containers
- View 3-pane comparison (Source | NMT | LLM)
- Vote for your preferred translation
- Download CSV with ratings

---

## 💰 Cost Estimation

### Development Environment (Free Tier)
- Azure Translator (F0): **$0/month** (2M chars/month free)
- App Service (F1): **$0/month** (Free tier)
- Storage (LRS): **~$0.50/month**
- Application Insights: **~$2/month** (first 5GB free)
- AI Foundry (GPT-4o-mini): **Pay per use** (~$0.15/1M input tokens)

**Total: ~$2.50/month + minimal LLM usage**

### Production Environment
- Azure Translator (S1): **~$10/month** (base) + usage
- App Service (P1v3): **~$80/month**
- Storage (GRS): **~$5/month**
- Application Insights: **~$10/month**
- AI Foundry: **Pay per use**

**Total: ~$105/month + translation volume**

> 💡 **Tip**: Start with Free tier to test, then upgrade based on usage.

---

## 🚨 Troubleshooting

### Issue: "Frontend shows no dropdowns or buttons don't work"

**Cause**: Frontend not connecting to backend.

**Solution**:
1. Check browser console (F12) for errors
2. Verify CORS is configured:
   ```bash
   az webapp config appsettings set \
     --resource-group translator-dev-rg \
     --name <backend-app-name> \
     --settings BACKEND_CORS_ORIGINS='["https://<frontend-app>.azurewebsites.net"]'
   ```
3. Verify frontend was built with correct API URL
4. Restart both App Services

### Issue: "Storage/Batch features return 401/403 errors"

**Cause**: RBAC permissions not yet propagated or not assigned.

**Solution**:
1. Wait 5-10 minutes for Azure RBAC propagation
2. Verify role assignment:
   ```bash
   az role assignment list \
     --assignee $(az webapp identity show \
       --resource-group translator-dev-rg \
       --name <backend-app-name> \
       --query principalId --output tsv) \
     --scope $(az storage account show \
       --resource-group translator-dev-rg \
       --name <storage-account-name> \
       --query id --output tsv)
   ```
3. Re-assign if missing (see Step 7 in Azure deployment)

### Issue: "LLM translation returns errors"

**Cause**: AI Foundry not configured or deployment missing.

**Solution**:
1. Verify AI Foundry resource exists:
   ```bash
   az cognitiveservices account list \
     --resource-group translator-dev-rg \
     --query "[?kind=='AIServices']"
   ```
2. Verify GPT-4o-mini deployment:
   ```bash
   az cognitiveservices account deployment list \
     --resource-group translator-dev-rg \
     --name <ai-foundry-name>
   ```
3. Check backend environment variables include:
   - `AZURE_AI_FOUNDRY_ENDPOINT`
   - `AZURE_AI_FOUNDRY_KEY`
   - `GPT4O_MINI_DEPLOYMENT_NAME`

### Issue: "Deployment fails with 'InvalidTemplate'"

**Cause**: Bicep syntax error or missing parameters.

**Solution**:
1. Validate Bicep templates:
   ```bash
   cd infra/bicep
   az bicep build --file main.bicep
   ```
2. Check parameters file has all required values
3. Run with `--debug` flag for detailed errors

### Issue: "Python 3.9 TypeError with type hints"

**Cause**: Using Python 3.10+ union syntax with Python 3.9.

**Solution**: The codebase is compatible with Python 3.9+. If you see errors like `TypeError: unsupported operand type(s) for |`, ensure you're using the correct version or update to Python 3.10+.

---

## 📚 Additional Documentation

- **[Architecture Guide](docs/architecture.md)** - Detailed system architecture
- **[LLM Translation Guide](docs/llm-translation.md)** - GPT-4o/GPT-4o-mini features
- **[Troubleshooting Guide](docs/troubleshooting.md)** - Comprehensive issue resolution
- **[Azure Translator Docs](https://learn.microsoft.com/azure/ai-services/translator/)** - Official Microsoft docs
- **[Preview API Reference](https://learn.microsoft.com/azure/ai-services/translator/text-translation/preview/overview)** - 2025-05-01-preview API

---

## 🛠️ Development Tips

### Running Tests

```bash
# Backend tests
cd src/backend
python -m pytest tests/

# Frontend tests
cd src/frontend
npm test
```

### Code Formatting

```bash
# Backend (Python)
cd src/backend
black app/
isort app/

# Frontend (TypeScript)
cd src/frontend
npm run lint
npm run format
```

### Updating Dependencies

```bash
# Backend
cd src/backend
pip install --upgrade -r requirements.txt

# Frontend
cd src/frontend
npm update
```

---

## 🧹 Cleanup

### Delete Azure Resources

```bash
# Navigate to scripts directory
cd infra/scripts

# Run cleanup script
bash cleanup.sh dev

# Or for Windows PowerShell:
# .\cleanup.ps1 -Environment dev

# This will delete:
# - Resource group
# - All resources within it
# - Role assignments
```

**⚠️ Warning**: This action is irreversible. All data will be lost.

---

## 🤝 Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- Azure AI Translator Service team for comprehensive API documentation
- Microsoft Azure for excellent Bicep documentation and samples
- Open source community for FastAPI, React, and supporting libraries

---

## ❓ Need Help?

- **Issues**: [Open an issue](../../issues) on GitHub
- **Azure Translator**: [Microsoft Q&A](https://learn.microsoft.com/answers/tags/133/azure-translator)
- **General Azure**: [Azure Support](https://azure.microsoft.com/support/)

---

**Made with ❤️ for the Azure community**
