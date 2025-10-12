#!/bin/bash
# Quick frontend-only redeployment script

set -e

RESOURCE_PREFIX="${1:-fi89}"
ENVIRONMENT="${2:-dev}"
RESOURCE_GROUP_NAME="${RESOURCE_PREFIX}-${ENVIRONMENT}-rg"
BACKEND_APP_NAME="${RESOURCE_PREFIX}-${ENVIRONMENT}-api-hspipnmlmryzu"
FRONTEND_APP_NAME="${RESOURCE_PREFIX}-${ENVIRONMENT}-web-hspipnmlmryzu"
BACKEND_URL="https://${BACKEND_APP_NAME}.azurewebsites.net"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR/../.."

echo "🚀 Redeploying frontend..."
echo "   Resource Group: $RESOURCE_GROUP_NAME"
echo "   Frontend App: $FRONTEND_APP_NAME"
echo "   Backend URL: $BACKEND_URL"
echo ""

# First, configure App Service settings
echo "⚙️  Configuring App Service settings..."
az webapp config appsettings set \
    --name "$FRONTEND_APP_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --settings \
        "VITE_API_BASE_URL=$BACKEND_URL" \
        "ENVIRONMENT=$ENVIRONMENT" \
        "SCM_DO_BUILD_DURING_DEPLOYMENT=false" \
        "WEBSITE_NODE_DEFAULT_VERSION=18-lts" \
    --output none

cd "$PROJECT_ROOT/src/frontend"

# Build with correct API URL
echo "📦 Building frontend..."
VITE_API_BASE_URL="$BACKEND_URL" npm run build

# Create deployment package
echo "📦 Preparing deployment..."
TEMP_DEPLOY_DIR="/tmp/frontend-deploy-${RESOURCE_PREFIX}"
rm -rf "$TEMP_DEPLOY_DIR"
mkdir -p "$TEMP_DEPLOY_DIR"

# Copy built files
cp -r dist/* "$TEMP_DEPLOY_DIR/"

# Create Express server
cat > "$TEMP_DEPLOY_DIR/server.js" << 'EOF'
const express = require('express');
const path = require('path');
const app = express();

app.use(express.static(__dirname, { etag: true, maxAge: '1h' }));
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'index.html'));
});

const port = process.env.PORT || 8080;
app.listen(port, '0.0.0.0', () => {
  console.log(`Frontend server listening on port ${port}`);
});
EOF

# Create package.json
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

# Install dependencies
echo "📦 Installing Express..."
cd "$TEMP_DEPLOY_DIR"
npm install --production --silent 2>&1 | grep -v "npm WARN" || true

# Create zip
echo "📦 Creating deployment package..."
zip -r /tmp/frontend-${RESOURCE_PREFIX}.zip . >/dev/null 2>&1

# Deploy
echo "☁️  Uploading to Azure..."
az webapp deployment source config-zip \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$FRONTEND_APP_NAME" \
    --src "/tmp/frontend-${RESOURCE_PREFIX}.zip" \
    --output none

# Clean up
rm -rf "$TEMP_DEPLOY_DIR"
rm -f /tmp/frontend-${RESOURCE_PREFIX}.zip

echo ""
echo "✅ Frontend redeployed successfully!"
echo "🌐 Frontend URL: https://${FRONTEND_APP_NAME}.azurewebsites.net"
echo ""
echo "⏳ Wait 30-60 seconds for the app to restart, then test the translation features."

