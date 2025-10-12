# Azure Translator Solution Accelerator - Infrastructure Bootstrap Script (PowerShell)
# This script provisions all Azure resources using Bicep templates

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('dev', 'prod')]
    [string]$Environment = 'dev',
    
    [Parameter(Mandatory=$false)]
    [string]$Location = 'westeurope',
    
    [Parameter(Mandatory=$false)]
    [string]$ResourcePrefix = 'translator'
)

$ErrorActionPreference = 'Stop'

# Functions
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

# Check prerequisites
function Test-Prerequisites {
    Write-Header "Checking Prerequisites"
    
    # Check Azure CLI
    try {
        $azVersion = az version --query '\"azure-cli\"' -o tsv
        Write-Success "Azure CLI found: $azVersion"
    }
    catch {
        Write-Error "Azure CLI is not installed. Please install from: https://docs.microsoft.com/cli/azure/install-azure-cli"
        exit 1
    }
    
    # Check Bicep
    try {
        $bicepVersion = az bicep version
        Write-Success "Bicep CLI found: $bicepVersion"
    }
    catch {
        Write-Warning "Bicep CLI not found. Installing..."
        az bicep install
    }
}

# Variables
$ResourceGroupName = "$ResourcePrefix-$Environment-rg"
$DeploymentName = "$ResourcePrefix-$Environment-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

Write-Header "Azure Translator Solution Accelerator - Bootstrap"
Write-Info "Environment: $Environment"
Write-Info "Location: $Location"
Write-Info "Resource Group: $ResourceGroupName"
Write-Info "Deployment Name: $DeploymentName"

# Check prerequisites
Test-Prerequisites

# Login to Azure
Write-Header "Azure Authentication"
try {
    $account = az account show | ConvertFrom-Json
    Write-Success "Already logged in to Azure"
    Write-Info "Current subscription: $($account.name) ($($account.id))"
}
catch {
    Write-Info "Not logged in. Initiating Azure login..."
    az login
    $account = az account show | ConvertFrom-Json
}

# Confirm subscription
$confirmation = Read-Host "Continue with this subscription? (y/n)"
if ($confirmation -ne 'y') {
    Write-Info "Listing available subscriptions..."
    az account list --output table
    $subId = Read-Host "Enter subscription ID"
    az account set --subscription $subId
    $account = az account show | ConvertFrom-Json
    Write-Success "Switched to subscription: $($account.name)"
}

# Register resource providers
Write-Header "Registering Resource Providers"
$providers = @(
    'Microsoft.CognitiveServices',
    'Microsoft.Web',
    'Microsoft.Storage',
    'Microsoft.KeyVault',
    'Microsoft.Insights',
    'Microsoft.OperationalInsights'
)

foreach ($provider in $providers) {
    try {
        $status = az provider show --namespace $provider --query "registrationState" -o tsv
        if ($status -ne 'Registered') {
            Write-Info "Registering $provider..."
            az provider register --namespace $provider --wait
            Write-Success "$provider registered"
        }
        else {
            Write-Success "$provider already registered"
        }
    }
    catch {
        Write-Warning "Could not check $provider registration status"
    }
}

# Create resource group
Write-Header "Creating Resource Group"
try {
    $rgExists = az group show --name $ResourceGroupName 2>$null
    if ($rgExists) {
        Write-Warning "Resource group $ResourceGroupName already exists"
        $confirmation = Read-Host "Continue with existing resource group? (y/n)"
        if ($confirmation -ne 'y') {
            Write-Error "Deployment cancelled"
            exit 1
        }
    }
}
catch {
    az group create `
        --name $ResourceGroupName `
        --location $Location `
        --tags "Environment=$Environment" "Project=Translator-Accelerator" "ManagedBy=Bicep"
    Write-Success "Resource group created: $ResourceGroupName"
}

# Validate Bicep template
Write-Header "Validating Bicep Template"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BicepDir = Join-Path $ScriptDir '..\bicep'
$BicepFile = Join-Path $BicepDir 'main.bicep'
$ParamFile = Join-Path $BicepDir "parameters\$Environment.bicepparam"

if (-not (Test-Path $BicepFile)) {
    Write-Error "Bicep file not found: $BicepFile"
    exit 1
}

if (-not (Test-Path $ParamFile)) {
    Write-Error "Parameter file not found: $ParamFile"
    exit 1
}

Write-Info "Building Bicep template..."
az bicep build --file $BicepFile
Write-Success "Bicep template is valid"

# Deploy infrastructure
Write-Header "Deploying Infrastructure"
Write-Warning "This will provision Azure resources and may incur costs."
$confirmation = Read-Host "Proceed with deployment? (y/n)"
if ($confirmation -ne 'y') {
    Write-Error "Deployment cancelled"
    exit 1
}

Write-Info "Starting deployment... This may take 5-10 minutes."
Write-Info "Deployment name: $DeploymentName"

try {
    $deploymentOutput = az deployment group create `
        --name $DeploymentName `
        --resource-group $ResourceGroupName `
        --template-file $BicepFile `
        --parameters $ParamFile `
        --query "properties.outputs" `
        --output json | ConvertFrom-Json
    
    Write-Success "Deployment completed successfully!"
}
catch {
    Write-Error "Deployment failed. Check Azure Portal for details."
    Write-Error $_.Exception.Message
    exit 1
}

# Extract outputs
Write-Header "Deployment Summary"

$backendUrl = $deploymentOutput.backendAppUrl.value
$frontendUrl = $deploymentOutput.frontendAppUrl.value
$apiDocsUrl = "$backendUrl/docs"
$keyVaultName = $deploymentOutput.keyVaultName.value
$appInsightsName = $deploymentOutput.appInsightsName.value
$translatorName = $deploymentOutput.translatorName.value
$storageName = $deploymentOutput.storageName.value

Write-Host "`n"
Write-Success "✨ Deployment Complete! ✨"
Write-Host "`n"
Write-Host "🌐 Application URLs:" -ForegroundColor Cyan
Write-Host "   Backend API:    $backendUrl"
Write-Host "   Frontend Web:   $frontendUrl"
Write-Host "   API Docs:       $apiDocsUrl"
Write-Host "`n"
Write-Host "🔧 Azure Resources:" -ForegroundColor Cyan
Write-Host "   Resource Group: $ResourceGroupName"
Write-Host "   Translator:     $translatorName"
Write-Host "   Key Vault:      $keyVaultName"
Write-Host "   Storage:        $storageName"
Write-Host "   App Insights:   $appInsightsName"
Write-Host "`n"

# Post-deployment steps
Write-Header "Post-Deployment Steps"

Write-Host "1. Grant yourself Key Vault access (for local development):"
Write-Host "   `$userId = az ad signed-in-user show --query id -o tsv"
Write-Host "   az keyvault set-policy --name $keyVaultName --object-id `$userId --secret-permissions get list"
Write-Host ""
Write-Host "2. Configure local environment:"
Write-Host "   Copy-Item env.example .env"
Write-Host "   # Update .env with values from Key Vault"
Write-Host ""
Write-Host "3. Deploy application code:"
Write-Host "   cd src\backend; az webapp up --name <backend-app-name>"
Write-Host "   cd src\frontend; npm run build; az webapp up --name <frontend-app-name>"
Write-Host ""
Write-Host "4. View logs:"
Write-Host "   az webapp log tail --name <app-name> --resource-group $ResourceGroupName"
Write-Host ""

# Save deployment info
$deploymentInfoFile = Join-Path $ScriptDir "..\..\..\.deployment-$Environment.json"
$deploymentOutput | ConvertTo-Json -Depth 10 | Out-File $deploymentInfoFile
Write-Success "Deployment info saved to: $deploymentInfoFile"

Write-Header "Next Steps"
Write-Info "1. Review the deployment in Azure Portal"
Write-Info "2. Configure your local environment (.env file)"
Write-Info "3. Deploy application code using CI/CD or manual deployment"
Write-Info "4. Run tests: make test"
Write-Info "5. Access API docs: $apiDocsUrl"

Write-Success "Bootstrap complete! 🎉"

