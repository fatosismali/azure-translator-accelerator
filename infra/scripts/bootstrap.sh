#!/bin/bash
# Azure Translator Solution Accelerator - Infrastructure Bootstrap Script (Linux/macOS)
# This script provisions all Azure resources using Bicep templates

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

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed. Please install from: https://docs.microsoft.com/cli/azure/install-azure-cli"
        exit 1
    fi
    AZ_VERSION=$(az version --query '"azure-cli"' -o tsv 2>/dev/null || az version | grep azure-cli | cut -d'"' -f4)
    print_success "Azure CLI found: $AZ_VERSION"
    
    # Check Bicep
    if ! command -v bicep &> /dev/null; then
        print_warning "Bicep CLI not found. Installing..."
        az bicep install
    fi
    print_success "Bicep CLI found: $(az bicep version)"
    
    # Check jq (optional but helpful)
    if ! command -v jq &> /dev/null; then
        print_warning "jq not found. Install for better JSON parsing: https://stedolan.github.io/jq/"
    else
        print_success "jq found"
    fi
}

# Parse arguments
ENVIRONMENT="${1:-dev}"
LOCATION="${2:-westeurope}"
RESOURCE_PREFIX="${3:-translator}"

if [[ ! "$ENVIRONMENT" =~ ^(dev|prod)$ ]]; then
    print_error "Invalid environment. Use 'dev' or 'prod'"
    echo "Usage: $0 <environment> [location] [resource-prefix]"
    echo "Example: $0 dev westeurope translator"
    exit 1
fi

RESOURCE_GROUP_NAME="${RESOURCE_PREFIX}-${ENVIRONMENT}-rg"
DEPLOYMENT_NAME="${RESOURCE_PREFIX}-${ENVIRONMENT}-deployment-$(date +%Y%m%d-%H%M%S)"

print_header "Azure Translator Solution Accelerator - Bootstrap"
print_info "Environment: $ENVIRONMENT"
print_info "Location: $LOCATION"
print_info "Resource Group: $RESOURCE_GROUP_NAME"
print_info "Deployment Name: $DEPLOYMENT_NAME"

# Check prerequisites
check_prerequisites

# Login to Azure
print_header "Azure Authentication"
LOGGED_IN=$(az account show --query "id" -o tsv 2>/dev/null || echo "")
if [ -z "$LOGGED_IN" ]; then
    print_info "Not logged in. Initiating Azure login..."
    az login
else
    print_success "Already logged in to Azure"
fi

# Show current subscription
SUBSCRIPTION_NAME=$(az account show --query "name" -o tsv)
SUBSCRIPTION_ID=$(az account show --query "id" -o tsv)
print_info "Current subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"

# Confirm or select subscription
read -p "Continue with this subscription? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Listing available subscriptions..."
    az account list --output table
    read -p "Enter subscription ID: " SUB_ID
    az account set --subscription "$SUB_ID"
    print_success "Switched to subscription: $(az account show --query 'name' -o tsv)"
fi

# Register required resource providers
print_header "Registering Resource Providers"
PROVIDERS=(
    "Microsoft.CognitiveServices"
    "Microsoft.Web"
    "Microsoft.Storage"
    "Microsoft.KeyVault"
    "Microsoft.Insights"
    "Microsoft.OperationalInsights"
)

for provider in "${PROVIDERS[@]}"; do
    STATUS=$(az provider show --namespace "$provider" --query "registrationState" -o tsv 2>/dev/null || echo "NotRegistered")
    if [ "$STATUS" != "Registered" ]; then
        print_info "Registering $provider..."
        az provider register --namespace "$provider" --wait
        print_success "$provider registered"
    else
        print_success "$provider already registered"
    fi
done

# Create resource group
print_header "Creating Resource Group"
if az group show --name "$RESOURCE_GROUP_NAME" &>/dev/null; then
    print_warning "Resource group $RESOURCE_GROUP_NAME already exists"
    read -p "Continue with existing resource group? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Deployment cancelled"
        exit 1
    fi
else
    az group create \
        --name "$RESOURCE_GROUP_NAME" \
        --location "$LOCATION" \
        --tags "Environment=$ENVIRONMENT" "Project=Translator-Accelerator" "ManagedBy=Bicep"
    print_success "Resource group created: $RESOURCE_GROUP_NAME"
fi

# Validate Bicep template
print_header "Validating Bicep Template"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BICEP_DIR="$SCRIPT_DIR/../bicep"
BICEP_FILE="$BICEP_DIR/main.bicep"
PARAM_FILE="$BICEP_DIR/parameters/${ENVIRONMENT}.bicepparam"

if [ ! -f "$BICEP_FILE" ]; then
    print_error "Bicep file not found: $BICEP_FILE"
    exit 1
fi

if [ ! -f "$PARAM_FILE" ]; then
    print_error "Parameter file not found: $PARAM_FILE"
    exit 1
fi

print_info "Building Bicep template..."
az bicep build --file "$BICEP_FILE"
print_success "Bicep template is valid"

# Deploy infrastructure
print_header "Deploying Infrastructure"
print_warning "This will provision Azure resources and may incur costs."
read -p "Proceed with deployment? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_error "Deployment cancelled"
    exit 1
fi

print_info "Starting deployment... This may take 5-10 minutes."
print_info "Deployment name: $DEPLOYMENT_NAME"

DEPLOYMENT_OUTPUT=$(az deployment group create \
    --name "$DEPLOYMENT_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --template-file "$BICEP_FILE" \
    --parameters "$PARAM_FILE" \
    --query "properties.outputs" \
    --output json)

if [ $? -eq 0 ]; then
    print_success "Deployment completed successfully!"
else
    print_error "Deployment failed. Check Azure Portal for details."
    exit 1
fi

# Extract outputs
print_header "Deployment Summary"

if command -v jq &> /dev/null; then
    BACKEND_URL=$(echo "$DEPLOYMENT_OUTPUT" | jq -r '.backendAppUrl.value')
    FRONTEND_URL=$(echo "$DEPLOYMENT_OUTPUT" | jq -r '.frontendAppUrl.value')
    API_DOCS_URL="${BACKEND_URL}/docs"
    KEY_VAULT_NAME=$(echo "$DEPLOYMENT_OUTPUT" | jq -r '.keyVaultName.value')
    APP_INSIGHTS_NAME=$(echo "$DEPLOYMENT_OUTPUT" | jq -r '.appInsightsName.value')
    TRANSLATOR_NAME=$(echo "$DEPLOYMENT_OUTPUT" | jq -r '.translatorName.value')
    STORAGE_NAME=$(echo "$DEPLOYMENT_OUTPUT" | jq -r '.storageName.value')
    
    echo ""
    print_success "✨ Deployment Complete! ✨"
    echo ""
    echo "🌐 Application URLs:"
    echo "   Backend API:    $BACKEND_URL"
    echo "   Frontend Web:   $FRONTEND_URL"
    echo "   API Docs:       $API_DOCS_URL"
    echo ""
    echo "🔧 Azure Resources:"
    echo "   Resource Group: $RESOURCE_GROUP_NAME"
    echo "   Translator:     $TRANSLATOR_NAME"
    echo "   Key Vault:      $KEY_VAULT_NAME"
    echo "   Storage:        $STORAGE_NAME"
    echo "   App Insights:   $APP_INSIGHTS_NAME"
    echo ""
else
    print_success "Deployment outputs:"
    echo "$DEPLOYMENT_OUTPUT"
fi

# Post-deployment steps
print_header "Post-Deployment Steps"

echo "1. Grant yourself Key Vault access (for local development):"
echo "   USER_ID=\$(az ad signed-in-user show --query id -o tsv)"
echo "   az keyvault set-policy --name $KEY_VAULT_NAME --object-id \$USER_ID --secret-permissions get list"
echo ""
echo "2. Configure local environment:"
echo "   cp env.example .env"
echo "   # Update .env with values from Key Vault"
echo ""
echo "3. Deploy application code:"
echo "   cd src/backend && az webapp up --name <backend-app-name>"
echo "   cd src/frontend && npm run build && az webapp up --name <frontend-app-name>"
echo ""
echo "4. View logs:"
echo "   az webapp log tail --name <app-name> --resource-group $RESOURCE_GROUP_NAME"
echo ""
echo "5. Monitor application:"
echo "   az portal dashboard show --resource-group $RESOURCE_GROUP_NAME"
echo ""

# Save deployment info to file
DEPLOYMENT_INFO_FILE="$SCRIPT_DIR/../../.deployment-${ENVIRONMENT}.json"
echo "$DEPLOYMENT_OUTPUT" > "$DEPLOYMENT_INFO_FILE"
print_success "Deployment info saved to: $DEPLOYMENT_INFO_FILE"

print_header "Next Steps"
print_info "1. Review the deployment in Azure Portal"
print_info "2. Configure your local environment (.env file)"
print_info "3. Deploy application code using CI/CD or manual deployment"
print_info "4. Run tests: make test"
print_info "5. Access API docs: ${BACKEND_URL}/docs"

print_success "Bootstrap complete! 🎉"

