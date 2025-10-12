# Azure Translator Solution Accelerator - Cleanup Script (PowerShell)
# This script safely removes all Azure resources

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('dev', 'prod')]
    [string]$Environment = 'dev',
    
    [Parameter(Mandatory=$false)]
    [string]$ResourcePrefix = 'translator'
)

$ErrorActionPreference = 'Stop'

function Write-Header {
    param([string]$Message)
    Write-Host "`n==================================" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "==================================" -ForegroundColor Cyan
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

$ResourceGroupName = "$ResourcePrefix-$Environment-rg"

Write-Header "Azure Translator Solution Accelerator - Cleanup"
Write-Warning "This will DELETE all resources in: $ResourceGroupName"
Write-Warning "This action is IRREVERSIBLE!"

# Check if logged in
try {
    $account = az account show | ConvertFrom-Json
    Write-Info "Current subscription: $($account.name) ($($account.id))"
}
catch {
    Write-Error "Not logged in to Azure"
    az login
    $account = az account show | ConvertFrom-Json
}

# Check if resource group exists
try {
    $rgExists = az group show --name $ResourceGroupName 2>$null
    if (-not $rgExists) {
        Write-Warning "Resource group $ResourceGroupName does not exist"
        exit 0
    }
}
catch {
    Write-Warning "Resource group $ResourceGroupName does not exist"
    exit 0
}

# List resources
Write-Header "Resources to be Deleted"
az resource list --resource-group $ResourceGroupName --output table

# Confirmation
Write-Host "`n"
Write-Warning "⚠️  WARNING: This will delete ALL resources listed above!"
$confirmName = Read-Host "Type the resource group name to confirm"

if ($confirmName -ne $ResourceGroupName) {
    Write-Error "Confirmation failed. Resource group name doesn't match."
    exit 1
}

$finalConfirm = Read-Host "Are you absolutely sure? (yes/no)"
if ($finalConfirm -ne 'yes') {
    Write-Error "Cleanup cancelled"
    exit 0
}

# Delete resource group
Write-Header "Deleting Resources"
Write-Info "Deleting resource group: $ResourceGroupName"
Write-Info "This may take several minutes..."

az group delete `
    --name $ResourceGroupName `
    --yes `
    --no-wait

Write-Success "Deletion initiated"
Write-Info "You can monitor progress in Azure Portal or run:"
Write-Info "  az group show --name $ResourceGroupName"

# Check for soft-deleted Key Vault
Write-Header "Checking for Soft-Deleted Resources"
Write-Info "Checking for soft-deleted Key Vaults..."

try {
    $softDeletedKVs = az keyvault list-deleted --query "[?properties.tags.Environment=='$Environment'].name" -o tsv 2>$null
    
    if ($softDeletedKVs) {
        Write-Warning "Found soft-deleted Key Vaults:"
        Write-Host $softDeletedKVs
        $purgeKV = Read-Host "Purge soft-deleted Key Vaults? (y/n)"
        if ($purgeKV -eq 'y') {
            foreach ($kv in $softDeletedKVs.Split("`n")) {
                if ($kv.Trim()) {
                    Write-Info "Purging Key Vault: $kv"
                    az keyvault purge --name $kv.Trim() --no-wait
                }
            }
            Write-Success "Key Vault purge initiated"
        }
        else {
            Write-Info "Key Vaults will remain soft-deleted for 90 days"
            Write-Info "To purge manually: az keyvault purge --name <vault-name>"
        }
    }
    else {
        Write-Success "No soft-deleted Key Vaults found"
    }
}
catch {
    Write-Info "Could not check for soft-deleted Key Vaults"
}

# Clean up local deployment info
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$deploymentInfoFile = Join-Path $ScriptDir "..\..\..\.deployment-$Environment.json"
if (Test-Path $deploymentInfoFile) {
    Remove-Item $deploymentInfoFile
    Write-Success "Removed local deployment info"
}

Write-Header "Cleanup Summary"
Write-Success "Resource group deletion initiated: $ResourceGroupName"
Write-Info "Resources will be fully deleted within 10-15 minutes"
Write-Info ""
Write-Info "To verify deletion:"
Write-Info "  az group show --name $ResourceGroupName"
Write-Info ""
Write-Info "To check deletion status:"
Write-Info "  az group list --query `"[?name=='$ResourceGroupName']`" -o table"

Write-Success "Cleanup complete! 🗑️"

