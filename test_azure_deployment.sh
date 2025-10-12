#!/bin/bash

# Azure Deployment Test Script
# Run this to verify all components are working

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     Testing Azure Translator Accelerator Deployment        ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

FRONTEND_URL="https://translator-dev-web-zkavo6qequjns.azurewebsites.net"
BACKEND_URL="https://translator-dev-api-zkavo6qequjns.azurewebsites.net"

echo "🌐 1. Testing Frontend..."
FRONTEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$FRONTEND_URL")
if [ "$FRONTEND_STATUS" = "200" ]; then
    echo "   ✅ Frontend is up (HTTP $FRONTEND_STATUS)"
    echo "   URL: $FRONTEND_URL"
else
    echo "   ❌ Frontend failed (HTTP $FRONTEND_STATUS)"
fi
echo ""

echo "🔧 2. Testing Backend API..."
BACKEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BACKEND_URL")
if [ "$BACKEND_STATUS" = "200" ] || [ "$BACKEND_STATUS" = "405" ]; then
    echo "   ✅ Backend is up (HTTP $BACKEND_STATUS)"
    echo "   URL: $BACKEND_URL"
else
    echo "   ❌ Backend failed (HTTP $BACKEND_STATUS)"
fi
echo ""

echo "🌍 3. Testing Languages API..."
LANG_RESPONSE=$(curl -s "$BACKEND_URL/api/v1/languages")
LANG_COUNT=$(echo "$LANG_RESPONSE" | python3 -c "import sys, json; d=json.load(sys.stdin); print(len(d.get('translation', {})))" 2>/dev/null)
if [ -n "$LANG_COUNT" ] && [ "$LANG_COUNT" -gt 0 ]; then
    echo "   ✅ Languages API working ($LANG_COUNT languages available)"
else
    echo "   ❌ Languages API failed"
fi
echo ""

echo "🔄 4. Testing Translation API..."
TRANS_RESPONSE=$(curl -s -X POST "$BACKEND_URL/api/v1/translate" \
    -H "Content-Type: application/json" \
    -d '{"text":"Hello world","from":"en","to":["es"]}')
TRANS_TEXT=$(echo "$TRANS_RESPONSE" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d['translations'][0]['translations'][0]['text'])" 2>/dev/null)
if [ -n "$TRANS_TEXT" ]; then
    echo "   ✅ Translation working: 'Hello world' → '$TRANS_TEXT'"
else
    echo "   ❌ Translation failed"
    echo "   Response: $TRANS_RESPONSE"
fi
echo ""

echo "💾 5. Testing Storage/Batch API..."
STORAGE_RESPONSE=$(curl -s "$BACKEND_URL/api/v1/batch/containers")
CONTAINER_COUNT=$(echo "$STORAGE_RESPONSE" | python3 -c "import sys, json; d=json.load(sys.stdin); print(len(d)) if isinstance(d, list) else print('error')" 2>/dev/null)
if [ "$CONTAINER_COUNT" != "error" ] && [ -n "$CONTAINER_COUNT" ]; then
    echo "   ✅ Storage access working ($CONTAINER_COUNT containers found)"
else
    ERROR_MSG=$(echo "$STORAGE_RESPONSE" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('detail', 'Unknown error')[:100])" 2>/dev/null)
    if echo "$ERROR_MSG" | grep -q "AuthorizationFailure"; then
        echo "   ⏳ Storage access pending (RBAC still propagating)"
        echo "   This can take 5-10 minutes after role assignment"
    else
        echo "   ❌ Storage failed: $ERROR_MSG"
    fi
fi
echo ""

echo "╔════════════════════════════════════════════════════════════╗"
echo "║                    TEST COMPLETE                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "📝 If storage is still pending, wait a few minutes and run this script again:"
echo "   bash test_azure_deployment.sh"
echo ""

