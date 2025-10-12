# Troubleshooting Guide

Common issues, their causes, and solutions for the Azure Translator Solution Accelerator.

## Quick Diagnostics

### Health Check

```bash
# Check backend health
curl http://localhost:8000/health

# Expected response:
# {"status": "healthy", "version": "1.0.0", "timestamp": "2025-10-10T12:00:00Z"}
```

### Verify Configuration

```bash
# Check environment variables
env | grep AZURE

# Verify Azure CLI authentication
az account show

# Test Translator connectivity
curl -X POST "https://api.cognitive.microsofttranslator.com/translate?api-version=3.0&to=es" \
  -H "Ocp-Apim-Subscription-Key: YOUR_KEY" \
  -H "Ocp-Apim-Subscription-Region: westeurope" \
  -H "Content-Type: application/json" \
  -d '[{"Text":"Hello"}]'
```

## Common Issues

### 1. Authentication Failures

#### Symptom
```
Error: (Unauthorized) Access denied due to invalid subscription key
```

#### Causes & Solutions

**Cause**: Invalid or missing Translator API key

**Solution**:
```bash
# Verify key in Azure Portal
az cognitiveservices account keys list \
  --name translator-dev-translator \
  --resource-group translator-dev-rg

# Update environment variable
export AZURE_TRANSLATOR_KEY="your-correct-key"

# Or update in Key Vault
az keyvault secret set \
  --vault-name translator-dev-kv \
  --name translator-api-key \
  --value "your-correct-key"
```

**Cause**: Wrong region configured

**Solution**:
```bash
# Check resource region
az cognitiveservices account show \
  --name translator-dev-translator \
  --resource-group translator-dev-rg \
  --query location -o tsv

# Update environment variable to match
export AZURE_TRANSLATOR_REGION="westeurope"  # or your region
```

**Cause**: Managed Identity not configured

**Solution**:
```bash
# Enable system-assigned managed identity
az webapp identity assign \
  --name translator-dev-api \
  --resource-group translator-dev-rg

# Grant Key Vault access
IDENTITY_ID=$(az webapp identity show \
  --name translator-dev-api \
  --resource-group translator-dev-rg \
  --query principalId -o tsv)

az keyvault set-policy \
  --name translator-dev-kv \
  --object-id $IDENTITY_ID \
  --secret-permissions get list
```

### 2. Rate Limiting (429 Errors)

#### Symptom
```json
{
  "error": {
    "code": "429",
    "message": "Rate limit is exceeded. Try again later."
  }
}
```

#### Causes & Solutions

**Cause**: Exceeded Translator API quota

**Solution**:
```bash
# Check current usage in Application Insights
az monitor app-insights query \
  --app translator-dev-ai \
  --analytics-query "
    customMetrics
    | where name == 'translation.characters'
    | where timestamp > ago(1d)
    | summarize sum(value)
  "

# Options:
# 1. Wait for quota reset (daily/monthly)
# 2. Upgrade to higher tier
# 3. Implement caching to reduce API calls
```

**Cause**: Too many concurrent requests

**Solution**: Implement exponential backoff (already in code):
```python
# In src/backend/app/services/translator_service.py
# Automatic retry with exponential backoff on 429
```

**Cause**: No rate limiting at application level

**Solution**: Enable rate limiting in configuration:
```bash
# Update .env
RATE_LIMIT_ENABLED=true
RATE_LIMIT_PER_MINUTE=60
```

### 3. Deployment Failures

#### Symptom
```
Error: The subscription is not registered to use namespace 'Microsoft.CognitiveServices'
```

#### Solution
```bash
# Register required resource providers
az provider register --namespace Microsoft.CognitiveServices
az provider register --namespace Microsoft.Web
az provider register --namespace Microsoft.Storage
az provider register --namespace Microsoft.KeyVault
az provider register --namespace Microsoft.Insights

# Check registration status
az provider show --namespace Microsoft.CognitiveServices --query "registrationState"
```

#### Symptom
```
Error: Resource name 'translator-dev-api' is already taken
```

#### Solution
```bash
# Resources must be globally unique. Add random suffix:
export UNIQUE_SUFFIX=$(openssl rand -hex 4)
export RESOURCE_PREFIX="translator-${UNIQUE_SUFFIX}"

# Redeploy with unique names
make deploy ENV=dev
```

#### Symptom
```
Error: Bicep build failed
```

#### Solution
```bash
# Validate Bicep templates
az bicep build --file infra/bicep/main.bicep

# Check for syntax errors
bicep lint infra/bicep/main.bicep

# Update Bicep CLI to latest
az bicep upgrade
```

### 4. Key Vault Access Issues

#### Symptom
```
Error: The user, group or application does not have secrets get permission
```

#### Solution
```bash
# Grant your user account access (for local dev)
MY_USER_ID=$(az ad signed-in-user show --query id -o tsv)

az keyvault set-policy \
  --name translator-dev-kv \
  --object-id $MY_USER_ID \
  --secret-permissions get list

# For App Service (if using Managed Identity)
APP_IDENTITY=$(az webapp identity show \
  --name translator-dev-api \
  --resource-group translator-dev-rg \
  --query principalId -o tsv)

az keyvault set-policy \
  --name translator-dev-kv \
  --object-id $APP_IDENTITY \
  --secret-permissions get list
```

#### Symptom
```
Error: Key Vault 'translator-dev-kv' not found
```

#### Solution
```bash
# Check if Key Vault exists
az keyvault list --query "[?contains(name, 'translator')]" -o table

# If soft-deleted, recover it
az keyvault recover --name translator-dev-kv

# Or purge and redeploy (WARNING: loses all secrets)
az keyvault purge --name translator-dev-kv
make deploy ENV=dev
```

### 5. Frontend Connection Issues

#### Symptom
Frontend shows "Network Error" or "Failed to fetch"

#### Causes & Solutions

**Cause**: CORS not configured

**Solution**:
```python
# In src/backend/app/main.py
# Ensure frontend URL is in CORS origins
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://localhost:5173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

**Cause**: Backend not running

**Solution**:
```bash
# Check backend logs
docker compose logs backend

# Or if running directly
cd src/backend
python -m app.main
```

**Cause**: Wrong API URL configured

**Solution**:
```bash
# Update frontend .env
echo "VITE_API_BASE_URL=http://localhost:8000" > src/frontend/.env.local

# Rebuild frontend
cd src/frontend
npm run dev
```

### 6. Docker Issues

#### Symptom
```
Error: Cannot connect to the Docker daemon
```

#### Solution
```bash
# Start Docker Desktop (macOS/Windows)
# Or start Docker service (Linux)
sudo systemctl start docker

# Verify Docker is running
docker ps
```

#### Symptom
```
Error: Port 8000 is already in use
```

#### Solution
```bash
# Find process using port
lsof -i :8000  # macOS/Linux
netstat -ano | findstr :8000  # Windows

# Kill process or use different port
# Update docker-compose.yml ports section
```

#### Symptom
```
Error: Image build failed
```

#### Solution
```bash
# Clear Docker cache
docker system prune -a

# Rebuild without cache
docker compose build --no-cache

# Check Dockerfile syntax
docker build -f src/backend/Dockerfile src/backend
```

### 7. Application Insights Not Receiving Data

#### Symptom
No telemetry in Application Insights

#### Causes & Solutions

**Cause**: Connection string not configured

**Solution**:
```bash
# Get connection string
az monitor app-insights component show \
  --app translator-dev-ai \
  --resource-group translator-dev-rg \
  --query connectionString -o tsv

# Set environment variable
export APPLICATIONINSIGHTS_CONNECTION_STRING="InstrumentationKey=...;IngestionEndpoint=..."
```

**Cause**: Telemetry disabled in code

**Solution**:
```bash
# Enable telemetry in .env
ENABLE_TELEMETRY=true

# Restart application
make local-run
```

**Cause**: Firewall blocking telemetry

**Solution**: Whitelist Application Insights endpoints:
- `dc.services.visualstudio.com`
- `*.in.applicationinsights.azure.com`

### 8. Translation Quality Issues

#### Symptom
Incorrect or poor-quality translations

#### Causes & Solutions

**Cause**: Wrong language code

**Solution**: Use ISO 639-1 codes:
```bash
# List supported languages
curl "http://localhost:8000/api/v1/languages"

# Common codes: en, es, fr, de, zh-Hans, ja, ar
```

**Cause**: Text contains unsupported characters

**Solution**: 
- Translator supports Unicode text
- Check for control characters or invalid UTF-8
- Validate input before sending

**Cause**: Context missing for ambiguous terms

**Solution**: 
- Use longer text for better context
- Consider custom translation models for domain-specific terms

### 9. Performance Issues

#### Symptom
Slow response times (> 2 seconds)

#### Diagnosis
```bash
# Check Application Insights for slow requests
az monitor app-insights query \
  --app translator-dev-ai \
  --analytics-query "
    requests
    | where timestamp > ago(1h)
    | where duration > 2000
    | summarize count=count() by name
  "
```

#### Solutions

**Solution 1: Enable caching**
```bash
# Update .env
ENABLE_CACHING=true

# Restart application
```

**Solution 2: Scale up App Service**
```bash
az appservice plan update \
  --name translator-dev-asp \
  --resource-group translator-dev-rg \
  --sku P1V3
```

**Solution 3: Optimize API calls**
- Use batch translation for multiple texts
- Implement request debouncing in frontend
- Cache frequently translated content

### 10. Storage Issues

#### Symptom
```
Error: The specified container does not exist
```

#### Solution
```bash
# Create storage container
az storage container create \
  --name translations \
  --account-name translatordevst \
  --auth-mode login

# Or run data ingestion script
cd data/ingestion
python load_samples.py
```

#### Symptom
```
Error: Authorization failure on storage account
```

#### Solution
```bash
# Grant App Service access to storage
APP_IDENTITY=$(az webapp identity show \
  --name translator-dev-api \
  --resource-group translator-dev-rg \
  --query principalId -o tsv)

az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee $APP_IDENTITY \
  --scope "/subscriptions/YOUR_SUB/resourceGroups/translator-dev-rg/providers/Microsoft.Storage/storageAccounts/translatordevst"
```

## Debugging Tips

### Enable Debug Logging

```bash
# Backend
LOG_LEVEL=DEBUG python -m app.main

# Frontend
VITE_DEBUG=true npm run dev
```

### View Application Logs

```bash
# Local (Docker)
docker compose logs -f backend

# Azure App Service
az webapp log tail \
  --name translator-dev-api \
  --resource-group translator-dev-rg

# Download logs
az webapp log download \
  --name translator-dev-api \
  --resource-group translator-dev-rg \
  --log-file logs.zip
```

### Test Translator API Directly

```bash
# Save as test_translator.sh
#!/bin/bash
KEY="your-key"
REGION="westeurope"

curl -X POST "https://api.cognitive.microsofttranslator.com/translate?api-version=3.0&to=es" \
  -H "Ocp-Apim-Subscription-Key: $KEY" \
  -H "Ocp-Apim-Subscription-Region: $REGION" \
  -H "Content-Type: application/json" \
  -d '[{"Text":"Hello, world!"}]' \
  -v

# Run: bash test_translator.sh
```

### Check Resource Status

```bash
# Check all resources in resource group
az resource list \
  --resource-group translator-dev-rg \
  --query "[].{Name:name, Type:type, Status:provisioningState}" \
  --output table

# Check App Service status
az webapp show \
  --name translator-dev-api \
  --resource-group translator-dev-rg \
  --query "{State:state, DefaultHostName:defaultHostName}"
```

## Getting Help

### Collect Diagnostic Information

Before opening an issue, collect:

```bash
# 1. Version information
cat README.md | grep "Version"
python --version
node --version
az --version

# 2. Environment details
env | grep -E "(AZURE|VITE)" > env_vars.txt

# 3. Recent logs
docker compose logs --tail=100 > docker_logs.txt

# 4. Application Insights errors (last hour)
az monitor app-insights query \
  --app translator-dev-ai \
  --analytics-query "
    exceptions
    | where timestamp > ago(1h)
    | project timestamp, type, outerMessage, details
  " > app_insights_errors.json
```

### Support Resources

- **GitHub Issues**: [github.com/yourrepo/issues](https://github.com/yourrepo/issues)
- **Azure Support**: [Azure Portal → Support](https://portal.azure.com/#blade/Microsoft_Azure_Support/HelpAndSupportBlade)
- **Translator Docs**: [learn.microsoft.com/azure/ai-services/translator](https://learn.microsoft.com/azure/ai-services/translator/)
- **Community**: [Stack Overflow - azure-translator](https://stackoverflow.com/questions/tagged/azure-translator)

### Escalation Path

1. Check this troubleshooting guide
2. Search closed GitHub issues
3. Review Application Insights for patterns
4. Open GitHub issue with diagnostic info
5. For production issues: Contact Azure Support

## Prevention

### Pre-Deployment Checklist

- [ ] Bicep templates validated (`make validate`)
- [ ] All tests passing (`make test`)
- [ ] Environment variables configured
- [ ] Azure subscription has quota for required services
- [ ] Resource providers registered
- [ ] Unique resource names (avoid conflicts)

### Monitoring Setup

- [ ] Application Insights configured
- [ ] Alerts set up for error rate and latency
- [ ] Quota tracking enabled
- [ ] Cost alerts configured
- [ ] Runbooks documented

### Regular Maintenance

- [ ] Review Application Insights weekly
- [ ] Update dependencies monthly
- [ ] Rotate secrets quarterly
- [ ] Load test before major releases
- [ ] Review and update documentation

---

**Last Updated:** 2025-10-10  
**Maintainers:** DevOps Team

For additional help, see [docs/architecture.md](./architecture.md) and [docs/observability.md](./observability.md).

