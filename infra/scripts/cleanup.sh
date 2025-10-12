#!/bin/bash
# Azure Translator Solution Accelerator - Cleanup Script (Linux/macOS)
# This script safely removes all Azure resources

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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
RESOURCE_PREFIX="${2:-translator}"

if [[ ! "$ENVIRONMENT" =~ ^(dev|prod)$ ]]; then
    print_error "Invalid environment. Use 'dev' or 'prod'"
    echo "Usage: $0 <environment> [resource-prefix]"
    echo "Example: $0 dev translator"
    exit 1
fi

RESOURCE_GROUP_NAME="${RESOURCE_PREFIX}-${ENVIRONMENT}-rg"

print_header "Azure Translator Solution Accelerator - Cleanup"
print_warning "This will DELETE all resources in: $RESOURCE_GROUP_NAME"
print_warning "This action is IRREVERSIBLE!"

# Check if logged in
LOGGED_IN=$(az account show --query "id" -o tsv 2>/dev/null || echo "")
if [ -z "$LOGGED_IN" ]; then
    print_error "Not logged in to Azure"
    az login
fi

# Show current subscription
SUBSCRIPTION_NAME=$(az account show --query "name" -o tsv)
SUBSCRIPTION_ID=$(az account show --query "id" -o tsv)
print_info "Current subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"

# Check if resource group exists
if ! az group show --name "$RESOURCE_GROUP_NAME" &>/dev/null; then
    print_warning "Resource group $RESOURCE_GROUP_NAME does not exist"
    exit 0
fi

# List resources that will be deleted
print_header "Resources to be Deleted"
az resource list --resource-group "$RESOURCE_GROUP_NAME" --output table

# Confirmation
echo ""
print_warning "⚠️  WARNING: This will delete ALL resources listed above!"
read -p "Type the resource group name to confirm: " CONFIRM_NAME

if [ "$CONFIRM_NAME" != "$RESOURCE_GROUP_NAME" ]; then
    print_error "Confirmation failed. Resource group name doesn't match."
    exit 1
fi

read -p "Are you absolutely sure? (yes/no): " FINAL_CONFIRM
if [ "$FINAL_CONFIRM" != "yes" ]; then
    print_error "Cleanup cancelled"
    exit 0
fi

# Delete resource group
print_header "Deleting Resources"
print_info "Deleting resource group: $RESOURCE_GROUP_NAME"
print_info "This may take several minutes..."

az group delete \
    --name "$RESOURCE_GROUP_NAME" \
    --yes \
    --no-wait

print_success "Deletion initiated"
print_info "You can monitor progress in Azure Portal or run:"
print_info "  az group show --name $RESOURCE_GROUP_NAME"

# Check for soft-deleted Key Vault
print_header "Checking for Soft-Deleted Resources"
print_info "Checking for soft-deleted Key Vaults..."

SOFT_DELETED_KVS=$(az keyvault list-deleted \
    --query "[?properties.tags.Environment=='$ENVIRONMENT'].name" \
    -o tsv 2>/dev/null || echo "")

if [ -n "$SOFT_DELETED_KVS" ]; then
    print_warning "Found soft-deleted Key Vaults:"
    echo "$SOFT_DELETED_KVS"
    read -p "Purge soft-deleted Key Vaults? (y/n): " PURGE_KV
    if [[ $PURGE_KV =~ ^[Yy]$ ]]; then
        for kv in $SOFT_DELETED_KVS; do
            print_info "Purging Key Vault: $kv"
            az keyvault purge --name "$kv" --no-wait
        done
        print_success "Key Vault purge initiated"
    else
        print_info "Key Vaults will remain soft-deleted for 90 days"
        print_info "To purge manually: az keyvault purge --name <vault-name>"
    fi
else
    print_success "No soft-deleted Key Vaults found"
fi

# Clean up local deployment info
DEPLOYMENT_INFO_FILE="$(dirname "$0")/../../.deployment-${ENVIRONMENT}.json"
if [ -f "$DEPLOYMENT_INFO_FILE" ]; then
    rm "$DEPLOYMENT_INFO_FILE"
    print_success "Removed local deployment info"
fi

print_header "Cleanup Summary"
print_success "Resource group deletion initiated: $RESOURCE_GROUP_NAME"
print_info "Resources will be fully deleted within 10-15 minutes"
print_info ""
print_info "To verify deletion:"
print_info "  az group show --name $RESOURCE_GROUP_NAME"
print_info ""
print_info "To check deletion status:"
print_info "  az group list --query \"[?name=='$RESOURCE_GROUP_NAME']\" -o table"

print_success "Cleanup complete! 🗑️"

