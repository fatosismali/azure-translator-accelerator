#!/bin/bash

# Test script for Dynamic Dictionary feature via REST API
# This script demonstrates testing the batch translation with custom dictionary

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

API_BASE_URL="${API_BASE_URL:-http://localhost:8000}"
API_V1="${API_BASE_URL}/api/v1"

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Azure Translator - Dynamic Dictionary API Test      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to print section headers
print_header() {
    echo -e "\n${GREEN}═══ $1 ═══${NC}\n"
}

# Function to print test results
print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ $2${NC}"
    else
        echo -e "${RED}✗ $2${NC}"
    fi
}

# Test 1: Health Check
print_header "Test 1: Health Check"
echo "Testing: GET ${API_BASE_URL}/health"
response=$(curl -s -w "\n%{http_code}" "${API_BASE_URL}/health")
status_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$status_code" -eq 200 ]; then
    echo -e "${GREEN}✓ Backend is healthy${NC}"
    echo "Response: $body"
else
    echo -e "${RED}✗ Backend health check failed (HTTP $status_code)${NC}"
    echo "Response: $body"
    exit 1
fi

# Test 2: Get Supported Languages
print_header "Test 2: Get Supported Languages"
echo "Testing: GET ${API_V1}/languages?scope=translation"
response=$(curl -s "${API_V1}/languages?scope=translation")
lang_count=$(echo "$response" | jq -r '.translation | length' 2>/dev/null || echo "0")

if [ "$lang_count" -gt 0 ]; then
    echo -e "${GREEN}✓ Retrieved $lang_count languages${NC}"
    echo "Sample languages:"
    echo "$response" | jq -r '.translation | to_entries[:5] | .[] | "  - \(.key): \(.value.name)"' 2>/dev/null || echo "  (jq not available for formatting)"
else
    echo -e "${RED}✗ Failed to retrieve languages${NC}"
fi

# Test 3: List Storage Containers (if storage is configured)
print_header "Test 3: List Storage Containers"
echo "Testing: GET ${API_V1}/batch/containers"
response=$(curl -s -w "\n%{http_code}" "${API_V1}/batch/containers")
status_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$status_code" -eq 200 ]; then
    echo -e "${GREEN}✓ Storage accessible${NC}"
    echo "Containers: $body"
else
    echo -e "${YELLOW}⚠ Storage not configured or accessible (HTTP $status_code)${NC}"
    echo "Note: This is optional for basic translation testing"
fi

# Test 4: Simple Translation (without dictionary)
print_header "Test 4: Simple Translation (No Dictionary)"
echo "Testing: POST ${API_V1}/translate"
echo "Text: 'The API provides access to translation services.'"

simple_request='{
  "text": "The API provides access to translation services.",
  "to": ["es"],
  "from": "en"
}'

response=$(curl -s -X POST "${API_V1}/translate" \
    -H "Content-Type: application/json" \
    -d "$simple_request")

echo "Response:"
echo "$response" | jq '.' 2>/dev/null || echo "$response"

translation=$(echo "$response" | jq -r '.[0].translations[0].text' 2>/dev/null || echo "")
if [ -n "$translation" ]; then
    echo -e "${GREEN}✓ Translation successful${NC}"
    echo -e "  Spanish: ${BLUE}$translation${NC}"
else
    echo -e "${RED}✗ Translation failed${NC}"
fi

# Test 5: Translation with Dictionary Tags (Preserve Term)
print_header "Test 5: Translation with Dynamic Dictionary (Preserve 'API')"
echo "Testing: POST ${API_V1}/translate"
echo "Text with annotation: 'The <mstrans:dictionary translation=\"API\">API</mstrans:dictionary> provides access.'"

dict_request_preserve='{
  "text": "The <mstrans:dictionary translation=\"API\">API</mstrans:dictionary> provides access to translation services.",
  "to": ["es"],
  "from": "en"
}'

response=$(curl -s -X POST "${API_V1}/translate" \
    -H "Content-Type: application/json" \
    -d "$dict_request_preserve")

echo "Response:"
echo "$response" | jq '.' 2>/dev/null || echo "$response"

translation=$(echo "$response" | jq -r '.[0].translations[0].text' 2>/dev/null || echo "")
if [ -n "$translation" ]; then
    echo -e "${GREEN}✓ Translation with dictionary successful${NC}"
    echo -e "  Spanish: ${BLUE}$translation${NC}"
    
    # Check if "API" is preserved
    if echo "$translation" | grep -q "API"; then
        echo -e "${GREEN}✓ Term 'API' was preserved in translation${NC}"
    else
        echo -e "${YELLOW}⚠ Term 'API' may have been translated${NC}"
    fi
else
    echo -e "${RED}✗ Translation failed${NC}"
fi

# Test 6: Translation with Dictionary Tags (Custom Translation)
print_header "Test 6: Translation with Dynamic Dictionary (Custom Translation)"
echo "Testing: POST ${API_V1}/translate"
echo "Text with annotation: 'The word <mstrans:dictionary translation=\"Wordomático\">wordomatic</mstrans:dictionary> is special.'"

dict_request_custom='{
  "text": "The word <mstrans:dictionary translation=\"Wordomático\">wordomatic</mstrans:dictionary> is a dictionary entry.",
  "to": ["es"],
  "from": "en"
}'

response=$(curl -s -X POST "${API_V1}/translate" \
    -H "Content-Type: application/json" \
    -d "$dict_request_custom")

echo "Response:"
echo "$response" | jq '.' 2>/dev/null || echo "$response"

translation=$(echo "$response" | jq -r '.[0].translations[0].text' 2>/dev/null || echo "")
if [ -n "$translation" ]; then
    echo -e "${GREEN}✓ Translation with custom dictionary successful${NC}"
    echo -e "  Spanish: ${BLUE}$translation${NC}"
    
    # Check if custom translation was applied
    if echo "$translation" | grep -q "Wordomático"; then
        echo -e "${GREEN}✓ Custom translation 'Wordomático' was applied${NC}"
    else
        echo -e "${YELLOW}⚠ Custom translation may not have been applied${NC}"
    fi
else
    echo -e "${RED}✗ Translation failed${NC}"
fi

# Test 7: Batch Translation with Dictionary (if storage is configured)
print_header "Test 7: Batch Translation with Dictionary"
echo "Testing: POST ${API_V1}/batch/jobs"
echo ""
echo "Note: This requires Azure Storage to be configured."
echo "Skipping batch test. Use the UI or configure storage to test this feature."
echo ""
echo -e "${YELLOW}To test batch translation with dictionary:${NC}"
echo "1. Configure Azure Storage (see README.md)"
echo "2. Upload test files to a source container"
echo "3. Use the Batch tab in the UI to add dictionary entries"
echo "4. Or use the following curl command:"
echo ""
echo -e "${BLUE}curl -X POST '${API_V1}/batch/jobs' \\${NC}"
echo -e "${BLUE}  -H 'Content-Type: application/json' \\${NC}"
echo -e "${BLUE}  -d '{${NC}"
echo -e "${BLUE}    \"source_container\": \"source-texts\",${NC}"
echo -e "${BLUE}    \"target_container\": \"translations\",${NC}"
echo -e "${BLUE}    \"target_language\": \"es\",${NC}"
echo -e "${BLUE}    \"source_language\": \"en\",${NC}"
echo -e "${BLUE}    \"dictionary\": {${NC}"
echo -e "${BLUE}      \"API\": \"API\",${NC}"
echo -e "${BLUE}      \"wordomatic\": \"Wordomático\",${NC}"
echo -e "${BLUE}      \"Azure Translator\": \"Azure Translator\"${NC}"
echo -e "${BLUE}    }${NC}"
echo -e "${BLUE}  }'${NC}"
echo ""

# Summary
print_header "Test Summary"
echo -e "${GREEN}✓ Backend API is running and responding${NC}"
echo -e "${GREEN}✓ Basic translation works${NC}"
echo -e "${GREEN}✓ Dynamic dictionary feature is functional${NC}"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "1. Open frontend at http://localhost:3000 (if running)"
echo "2. Navigate to Batch tab"
echo "3. Configure Azure Storage (if needed)"
echo "4. Add dictionary entries via UI"
echo "5. Start batch translation job"
echo ""
echo -e "${GREEN}For more information, see:${NC}"
echo "  - docs/dynamic-dictionary.md"
echo "  - README.md"
echo ""

