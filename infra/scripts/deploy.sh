#!/bin/bash
# Azure Translator Solution Accelerator - Application Deployment Script
# This script deploys application code and configures secrets

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_header() {
    echo ""
    echo "=================================="
    echo "$1"
    echo "=================================="
}

# Parse arguments
ENVIRONMENT="${1:-dev}"
RESOURCE_PREFIX="${2:-}"
AUTO_APPROVE="false"

# Check for --yes flag
for arg in "$@"; do
    if [[ "$arg" == "--yes" ]] || [[ "$arg" == "-y" ]]; then
        AUTO_APPROVE="true"
    fi
done

if [[ ! "$ENVIRONMENT" =~ ^(dev|prod)$ ]]; then
    print_error "Invalid environment. Use 'dev' or 'prod'"
    echo "Usage: $0 <environment> <resource-prefix> [--yes]"
    echo "Example: $0 dev fi89 --yes"
    exit 1
fi

if [ -z "$RESOURCE_PREFIX" ]; then
    print_error "Resource prefix is required"
    echo "Usage: $0 <environment> <resource-prefix> [--yes]"
    echo "Example: $0 dev fi89 --yes"
    exit 1
fi

RESOURCE_GROUP_NAME="${RESOURCE_PREFIX}-${ENVIRONMENT}-rg"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR/../.."

print_header "Azure Translator Solution Accelerator - Application Deployment"

print_info "Environment: $ENVIRONMENT"
print_info "Resource Prefix: $RESOURCE_PREFIX"
print_info "Resource Group: $RESOURCE_GROUP_NAME"

# Check if logged in
print_header "Azure Authentication"
LOGGED_IN=$(az account show --query "id" -o tsv 2>/dev/null || echo "")
if [ -z "$LOGGED_IN" ]; then
    print_error "Not logged in to Azure. Please run: az login"
    exit 1
fi
print_success "Logged in to Azure"

# Check if resource group exists
print_header "Verifying Infrastructure"
if ! az group show --name "$RESOURCE_GROUP_NAME" &>/dev/null; then
    print_error "Resource group $RESOURCE_GROUP_NAME not found"
    print_info "Please run bootstrap.sh first to provision infrastructure"
    exit 1
fi
print_success "Resource group found"

# Discover resources
print_info "Discovering deployed resources..."

# Get resource names with better error handling
TRANSLATOR_NAME=$(az cognitiveservices account list --resource-group "$RESOURCE_GROUP_NAME" --query "[?kind=='TextTranslation'].name | [0]" -o tsv 2>/dev/null || echo "")
AI_FOUNDRY_NAME=$(az cognitiveservices account list --resource-group "$RESOURCE_GROUP_NAME" --query "[?kind=='AIServices'].name | [0]" -o tsv 2>/dev/null || echo "")
STORAGE_NAME=$(az storage account list --resource-group "$RESOURCE_GROUP_NAME" --query "[0].name" -o tsv 2>/dev/null || echo "")
STORAGE_ID=$(az storage account show --name "$STORAGE_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query "id" -o tsv 2>/dev/null || echo "")
KEY_VAULT_NAME=$(az keyvault list --resource-group "$RESOURCE_GROUP_NAME" --query "[0].name" -o tsv 2>/dev/null || echo "")
APP_INSIGHTS_NAME=$(az monitor app-insights component list --resource-group "$RESOURCE_GROUP_NAME" --query "[0].name" -o tsv 2>/dev/null || echo "")
BACKEND_APP_NAME=$(az webapp list --resource-group "$RESOURCE_GROUP_NAME" --query "[?contains(name, 'api')].name | [0]" -o tsv 2>/dev/null || echo "")
FRONTEND_APP_NAME=$(az webapp list --resource-group "$RESOURCE_GROUP_NAME" --query "[?contains(name, 'web')].name | [0]" -o tsv 2>/dev/null || echo "")

# Verify all resources found
if [ -z "$TRANSLATOR_NAME" ] || [ -z "$STORAGE_NAME" ] || [ -z "$KEY_VAULT_NAME" ] || [ -z "$BACKEND_APP_NAME" ] || [ -z "$FRONTEND_APP_NAME" ]; then
    print_error "Could not find all required resources"
    print_info "Translator: ${TRANSLATOR_NAME:-NOT FOUND}"
    print_info "AI Foundry: ${AI_FOUNDRY_NAME:-NOT FOUND}"
    print_info "Storage: ${STORAGE_NAME:-NOT FOUND}"
    print_info "Key Vault: ${KEY_VAULT_NAME:-NOT FOUND}"
    print_info "Backend App: ${BACKEND_APP_NAME:-NOT FOUND}"
    print_info "Frontend App: ${FRONTEND_APP_NAME:-NOT FOUND}"
    exit 1
fi

print_success "All resources discovered"

# Get resource details
print_header "Retrieving Resource Configuration"

print_info "Getting Translator configuration..."
TRANSLATOR_ENDPOINT=$(az cognitiveservices account show --name "$TRANSLATOR_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query "properties.endpoint" -o tsv)
TRANSLATOR_KEY=$(az cognitiveservices account keys list --name "$TRANSLATOR_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query "key1" -o tsv)
TRANSLATOR_REGION=$(az cognitiveservices account show --name "$TRANSLATOR_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query "location" -o tsv)

if [ -n "$AI_FOUNDRY_NAME" ]; then
    print_info "Getting AI Foundry configuration..."
    AI_FOUNDRY_ENDPOINT=$(az cognitiveservices account show --name "$AI_FOUNDRY_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query "properties.endpoint" -o tsv)
    AI_FOUNDRY_KEY=$(az cognitiveservices account keys list --name "$AI_FOUNDRY_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query "key1" -o tsv)
fi

print_info "Getting Storage configuration..."
STORAGE_CONNECTION_STRING=$(az storage account show-connection-string --name "$STORAGE_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query "connectionString" -o tsv)

print_info "Getting Application Insights configuration..."
if [ -n "$APP_INSIGHTS_NAME" ]; then
    APP_INSIGHTS_KEY=$(az monitor app-insights component show --app "$APP_INSIGHTS_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query "instrumentationKey" -o tsv 2>/dev/null || echo "")
    APP_INSIGHTS_CONNECTION_STRING=$(az monitor app-insights component show --app "$APP_INSIGHTS_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query "connectionString" -o tsv 2>/dev/null || echo "")
fi

print_success "Configuration retrieved"

# Configure Key Vault secrets
print_header "Configuring Key Vault Secrets"

# Grant current user access to Key Vault
print_info "Granting Key Vault access..."
USER_OBJECT_ID=$(az ad signed-in-user show --query "id" -o tsv)

# Try to grant access and verify it worked
set +e  # Don't exit on error
az keyvault set-policy \
    --name "$KEY_VAULT_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --object-id "$USER_OBJECT_ID" \
    --secret-permissions get list set delete \
    --certificate-permissions get list \
    --key-permissions get list \
    --output none 2>&1

POLICY_EXIT_CODE=$?
set -e

if [ $POLICY_EXIT_CODE -eq 0 ]; then
    print_success "Key Vault access granted"
else
    print_warning "Key Vault policy may already be set, verifying access..."
    
    # Try to test access by listing secrets
    if az keyvault secret list --vault-name "$KEY_VAULT_NAME" --query "[0].name" -o tsv &>/dev/null; then
        print_success "Key Vault access verified"
    else
        print_error "Failed to access Key Vault"
        print_info "Attempting to grant permissions with elevated privileges..."
        
        # Try again without suppressing output to show the actual error
        az keyvault set-policy \
            --name "$KEY_VAULT_NAME" \
            --resource-group "$RESOURCE_GROUP_NAME" \
            --object-id "$USER_OBJECT_ID" \
            --secret-permissions get list set delete \
            --certificate-permissions get list \
            --key-permissions get list
        
        print_success "Key Vault access granted"
    fi
fi

print_info "Storing secrets in Key Vault..."

# Store secrets (using lowercase hyphenated names to match working deployment)
az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "translator-api-key" --value "$TRANSLATOR_KEY" --output none
az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "translator-endpoint" --value "$TRANSLATOR_ENDPOINT" --output none
az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "translator-region" --value "$TRANSLATOR_REGION" --output none
az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "storage-connection-string" --value "$STORAGE_CONNECTION_STRING" --output none

if [ -n "$AI_FOUNDRY_KEY" ]; then
    az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "ai-foundry-key" --value "$AI_FOUNDRY_KEY" --output none
    az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "ai-foundry-endpoint" --value "$AI_FOUNDRY_ENDPOINT" --output none
fi

if [ -n "$APP_INSIGHTS_KEY" ]; then
    az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "appinsights-instrumentation-key" --value "$APP_INSIGHTS_KEY" --output none
fi

if [ -n "$APP_INSIGHTS_CONNECTION_STRING" ]; then
    az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "appinsights-connection-string" --value "$APP_INSIGHTS_CONNECTION_STRING" --output none
fi

print_success "Secrets configured in Key Vault"

# Configure App Service settings
print_header "Configuring App Services"

print_info "Configuring Backend App Service..."

# Get Key Vault URI
KEY_VAULT_URI=$(az keyvault show --name "$KEY_VAULT_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query "properties.vaultUri" -o tsv)

# Enable managed identity for backend app
print_info "Enabling managed identity..."
BACKEND_IDENTITY=$(az webapp identity assign --name "$BACKEND_APP_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query "principalId" -o tsv)

# Grant backend app access to Key Vault
print_info "Granting backend app access to Key Vault..."
az keyvault set-policy \
    --name "$KEY_VAULT_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --object-id "$BACKEND_IDENTITY" \
    --secret-permissions get list \
    --output none

# Grant backend app access to Storage Account (for managed identity access)
print_info "Granting backend app access to Storage Account..."
az role assignment create \
    --assignee "$BACKEND_IDENTITY" \
    --role "Storage Blob Data Contributor" \
    --scope "$STORAGE_ID" \
    --output none 2>/dev/null || echo "  (Role may already be assigned)"

# Configure backend app settings
print_info "Setting backend environment variables..."

az webapp config appsettings set \
    --name "$BACKEND_APP_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --settings \
        "AZURE_TRANSLATOR_KEY=@Microsoft.KeyVault(VaultName=$KEY_VAULT_NAME;SecretName=translator-api-key)" \
        "AZURE_TRANSLATOR_ENDPOINT=@Microsoft.KeyVault(VaultName=$KEY_VAULT_NAME;SecretName=translator-endpoint)" \
        "AZURE_TRANSLATOR_REGION=@Microsoft.KeyVault(VaultName=$KEY_VAULT_NAME;SecretName=translator-region)" \
        "AZURE_STORAGE_ACCOUNT_NAME=$STORAGE_NAME" \
        "AZURE_KEY_VAULT_URL=$KEY_VAULT_URI" \
        "ENVIRONMENT=$ENVIRONMENT" \
        "SCM_DO_BUILD_DURING_DEPLOYMENT=true" \
    --output none

if [ -n "$AI_FOUNDRY_KEY" ]; then
    az webapp config appsettings set \
        --name "$BACKEND_APP_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --settings \
            "AZURE_AI_FOUNDRY_KEY=@Microsoft.KeyVault(VaultName=$KEY_VAULT_NAME;SecretName=ai-foundry-key)" \
            "AZURE_AI_FOUNDRY_ENDPOINT=@Microsoft.KeyVault(VaultName=$KEY_VAULT_NAME;SecretName=ai-foundry-endpoint)" \
        --output none
fi

if [ -n "$APP_INSIGHTS_CONNECTION_STRING" ]; then
    az webapp config appsettings set \
        --name "$BACKEND_APP_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --settings "APPLICATIONINSIGHTS_CONNECTION_STRING=$APP_INSIGHTS_CONNECTION_STRING" \
        --output none
fi

print_success "Backend app configured"

# Configure backend startup command (matching working fi89 deployment)
print_info "Setting backend startup command..."
az webapp config set \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$BACKEND_APP_NAME" \
    --startup-file "gunicorn -w 4 -k uvicorn.workers.UvicornWorker app.main:app" \
    --output none

print_success "Backend startup command set"

# Configure frontend app
print_info "Configuring Frontend App Service..."

FRONTEND_IDENTITY=$(az webapp identity assign --name "$FRONTEND_APP_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query "principalId" -o tsv)

az keyvault set-policy \
    --name "$KEY_VAULT_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --object-id "$FRONTEND_IDENTITY" \
    --secret-permissions get list \
    --output none

BACKEND_URL="https://${BACKEND_APP_NAME}.azurewebsites.net"

az webapp config appsettings set \
    --name "$FRONTEND_APP_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --settings \
        "VITE_API_BASE_URL=$BACKEND_URL" \
        "VITE_API_URL=$BACKEND_URL" \
        "NODE_ENV=production" \
        "ENVIRONMENT=$ENVIRONMENT" \
        "SCM_DO_BUILD_DURING_DEPLOYMENT=false" \
        "WEBSITE_NODE_DEFAULT_VERSION=20-lts" \
    --output none

if [ -n "$APP_INSIGHTS_CONNECTION_STRING" ]; then
    az webapp config appsettings set \
        --name "$FRONTEND_APP_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --settings \
            "VITE_APPINSIGHTS_CONNECTION_STRING=$APP_INSIGHTS_CONNECTION_STRING" \
            "APPLICATIONINSIGHTS_CONNECTION_STRING=$APP_INSIGHTS_CONNECTION_STRING" \
        --output none
fi

print_success "Frontend app configured"

# Deploy application code
print_header "Deploying Application Code"

if [ "$AUTO_APPROVE" = "false" ]; then
    read -p "Deploy application code now? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Skipping code deployment"
        print_info "To deploy manually later, run:"
        print_info "  cd $PROJECT_ROOT/src/backend && zip -r backend.zip . && az webapp deployment source config-zip --resource-group $RESOURCE_GROUP_NAME --name $BACKEND_APP_NAME --src backend.zip"
        print_info "  cd $PROJECT_ROOT/src/frontend && npm run build && zip -r frontend.zip dist && az webapp deployment source config-zip --resource-group $RESOURCE_GROUP_NAME --name $FRONTEND_APP_NAME --src frontend.zip"
        exit 0
    fi
fi

# Deploy backend
print_info "Deploying backend application..."
cd "$PROJECT_ROOT/src/backend"

# Create deployment package
print_info "Creating backend deployment package..."
zip -r /tmp/backend-${RESOURCE_PREFIX}.zip . -x "*.pyc" -x "__pycache__/*" -x "venv/*" -x ".git/*" >/dev/null 2>&1

print_info "Uploading backend to Azure..."
az webapp deployment source config-zip \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$BACKEND_APP_NAME" \
    --src "/tmp/backend-${RESOURCE_PREFIX}.zip" \
    --output none

print_success "Backend deployed"

# Deploy frontend
print_info "Deploying frontend application..."
cd "$PROJECT_ROOT/src/frontend"

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
    print_info "Installing frontend dependencies..."
    npm install --silent
fi

# Build frontend
print_info "Building frontend application..."
VITE_API_BASE_URL="$BACKEND_URL" npm run build

# Create a simple static server setup for Azure App Service
print_info "Preparing frontend for Azure deployment..."

# Create a temporary deployment directory
TEMP_DEPLOY_DIR="/tmp/frontend-deploy-${RESOURCE_PREFIX}"
rm -rf "$TEMP_DEPLOY_DIR"
mkdir -p "$TEMP_DEPLOY_DIR"

# Copy built files
cp -r dist/* "$TEMP_DEPLOY_DIR/"

# Create a simple Express server for serving static files
cat > "$TEMP_DEPLOY_DIR/server.js" << 'EOF'
const express = require('express');
const path = require('path');
const app = express();

// Serve static files from current directory
app.use(express.static(__dirname, {
  etag: true,
  maxAge: '1h'
}));

// Handle React Router - send all requests to index.html
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'index.html'));
});

const port = process.env.PORT || 8080;
app.listen(port, '0.0.0.0', () => {
  console.log(`Frontend server listening on port ${port}`);
});
EOF

# Create a minimal package.json with Express
cat > "$TEMP_DEPLOY_DIR/package.json" << 'EOF'
{
  "name": "translator-frontend",
  "version": "1.0.0",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2"
  }
}
EOF

# Create web.config for proper routing
cat > "$TEMP_DEPLOY_DIR/web.config" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <system.webServer>
    <rewrite>
      <rules>
        <rule name="React Routes" stopProcessing="true">
          <match url=".*" />
          <conditions logicalGrouping="MatchAll">
            <add input="{REQUEST_FILENAME}" matchType="IsFile" negate="true" />
            <add input="{REQUEST_FILENAME}" matchType="IsDirectory" negate="true" />
          </conditions>
          <action type="Rewrite" url="/index.html" />
        </rule>
      </rules>
    </rewrite>
    <staticContent>
      <mimeMap fileExtension=".json" mimeType="application/json" />
      <mimeMap fileExtension=".woff" mimeType="application/font-woff" />
      <mimeMap fileExtension=".woff2" mimeType="application/font-woff2" />
    </staticContent>
  </system.webServer>
</configuration>
EOF

# Install dependencies locally
print_info "Installing frontend dependencies..."
cd "$TEMP_DEPLOY_DIR"
npm install --production --silent 2>&1 | grep -v "npm WARN" || true

# Create deployment package
print_info "Creating frontend deployment package..."
zip -r /tmp/frontend-${RESOURCE_PREFIX}.zip . >/dev/null 2>&1

print_info "Configuring frontend startup command..."
az webapp config set \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$FRONTEND_APP_NAME" \
    --startup-file "node server.js" \
    --output none

print_info "Uploading frontend to Azure..."
az webapp deployment source config-zip \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$FRONTEND_APP_NAME" \
    --src "/tmp/frontend-${RESOURCE_PREFIX}.zip" \
    --output none

# Clean up
rm -rf "$TEMP_DEPLOY_DIR"

print_success "Frontend deployed"

# Clean up temp files
rm -f /tmp/backend-${RESOURCE_PREFIX}.zip /tmp/frontend-${RESOURCE_PREFIX}.zip

# Test endpoints
print_header "Testing Deployment"

print_info "Waiting for applications to start..."
sleep 15

FRONTEND_URL="https://${FRONTEND_APP_NAME}.azurewebsites.net"
BACKEND_HEALTH_URL="${BACKEND_URL}/health"

print_info "Testing backend health endpoint..."
BACKEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BACKEND_HEALTH_URL" || echo "000")

if [ "$BACKEND_STATUS" = "200" ]; then
    print_success "Backend is healthy"
else
    print_warning "Backend returned status $BACKEND_STATUS (may still be starting up)"
fi

print_info "Testing frontend..."
FRONTEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$FRONTEND_URL" || echo "000")

if [ "$FRONTEND_STATUS" = "200" ]; then
    print_success "Frontend is accessible"
else
    print_warning "Frontend returned status $FRONTEND_STATUS (may still be starting up)"
fi

# Deployment summary
print_header "Deployment Summary"

echo ""
print_success "✨ Deployment Complete! ✨"
echo ""
echo "🌐 Application URLs:"
echo "   Frontend:     $FRONTEND_URL"
echo "   Backend API:  $BACKEND_URL"
echo "   API Docs:     ${BACKEND_URL}/docs"
echo ""
echo "🔑 Secrets:"
echo "   Key Vault:    $KEY_VAULT_NAME"
echo "   All secrets stored and configured via managed identities"
echo ""
echo "📊 Monitoring:"
if [ -n "$APP_INSIGHTS_NAME" ]; then
    echo "   App Insights: $APP_INSIGHTS_NAME"
    echo "   View logs:    az webapp log tail --name $BACKEND_APP_NAME --resource-group $RESOURCE_GROUP_NAME"
fi
echo ""
echo "🔧 Management Commands:"
echo "   View backend logs:   az webapp log tail --name $BACKEND_APP_NAME --resource-group $RESOURCE_GROUP_NAME"
echo "   View frontend logs:  az webapp log tail --name $FRONTEND_APP_NAME --resource-group $RESOURCE_GROUP_NAME"
echo "   Restart backend:     az webapp restart --name $BACKEND_APP_NAME --resource-group $RESOURCE_GROUP_NAME"
echo "   Restart frontend:    az webapp restart --name $FRONTEND_APP_NAME --resource-group $RESOURCE_GROUP_NAME"
echo ""

# Create local .env file
print_header "Creating Local Development Configuration"

ENV_FILE="$PROJECT_ROOT/.env"
cat > "$ENV_FILE" << EOF
# Azure Translator Solution Accelerator - Local Development Configuration
# Generated on $(date)

# Translator Service
AZURE_TRANSLATOR_KEY=$TRANSLATOR_KEY
AZURE_TRANSLATOR_ENDPOINT=$TRANSLATOR_ENDPOINT
AZURE_TRANSLATOR_REGION=$TRANSLATOR_REGION

# AI Foundry (if available)
$([ -n "$AI_FOUNDRY_KEY" ] && echo "AZURE_AI_FOUNDRY_KEY=$AI_FOUNDRY_KEY" || echo "# AZURE_AI_FOUNDRY_KEY=<not configured>")
$([ -n "$AI_FOUNDRY_ENDPOINT" ] && echo "AZURE_AI_FOUNDRY_ENDPOINT=$AI_FOUNDRY_ENDPOINT" || echo "# AZURE_AI_FOUNDRY_ENDPOINT=<not configured>")

# Storage
AZURE_STORAGE_CONNECTION_STRING=$STORAGE_CONNECTION_STRING

# Application Insights
$([ -n "$APP_INSIGHTS_CONNECTION_STRING" ] && echo "APPLICATIONINSIGHTS_CONNECTION_STRING=$APP_INSIGHTS_CONNECTION_STRING" || echo "# APPLICATIONINSIGHTS_CONNECTION_STRING=<not configured>")

# Key Vault
AZURE_KEY_VAULT_URL=$KEY_VAULT_URI
KEY_VAULT_NAME=$KEY_VAULT_NAME

# Environment
ENVIRONMENT=$ENVIRONMENT

# CORS Origins (for backend)
BACKEND_CORS_ORIGINS=["http://localhost:3000","http://localhost:5173"]

# Backend URL (for frontend)
VITE_API_BASE_URL=$BACKEND_URL
EOF

print_success "Local .env file created: $ENV_FILE"
print_warning "Keep this file secure and do not commit to version control!"

print_success "Deployment complete! 🎉"

