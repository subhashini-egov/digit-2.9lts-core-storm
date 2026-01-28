#!/bin/bash
# Smoke tests for DIGIT core services

BASE_URL="${1:-http://localhost}"

echo "=== DIGIT Core Services Smoke Tests ==="
echo "Base URL: $BASE_URL"
echo ""

passed=0
failed=0

# Test 1: MDMS search (tenant master)
echo -n "1. MDMS search (tenant master)... "
response=$(curl -sS -X POST "$BASE_URL:18094/mdms-v2/v1/_search" \
  -H 'Content-Type: application/json' \
  -d '{"RequestInfo":{"apiId":"digit","ver":"1.0","ts":0},"MdmsCriteria":{"tenantId":"pg","moduleDetails":[{"moduleName":"tenant","masterDetails":[{"name":"tenants"}]}]}}' 2>&1)
if echo "$response" | grep -q "MdmsRes"; then
  echo -e "\033[32mPASS\033[0m"
  passed=$((passed + 1))
else
  echo -e "\033[31mFAIL\033[0m"
  failed=$((failed + 1))
fi

# Test 2: Localization cache-bust
echo -n "2. Localization cache-bust... "
response=$(curl -sS -X POST "$BASE_URL:18096/localization/messages/cache-bust" 2>&1)
if echo "$response" | grep -q "successful"; then
  echo -e "\033[32mPASS\033[0m"
  passed=$((passed + 1))
else
  echo -e "\033[31mFAIL\033[0m"
  failed=$((failed + 1))
fi

# Test 3: Localization search
echo -n "3. Localization search... "
response=$(curl -sS -X POST "$BASE_URL:18096/localization/messages/v1/_search?locale=en_IN&module=rainmaker-workbench&tenantId=pg" \
  -H 'Content-Type: application/json' \
  -d '{"RequestInfo":{"apiId":"Rainmaker","ver":".01","ts":""}}' 2>&1)
if echo "$response" | grep -q "messages"; then
  echo -e "\033[32mPASS\033[0m"
  passed=$((passed + 1))
else
  echo -e "\033[31mFAIL\033[0m"
  failed=$((failed + 1))
fi

# Test 4: User service health
echo -n "4. User service health... "
response=$(curl -sS "$BASE_URL:18107/user/health" 2>&1)
if echo "$response" | grep -q "UP"; then
  echo -e "\033[32mPASS\033[0m"
  passed=$((passed + 1))
else
  echo -e "\033[31mFAIL\033[0m"
  failed=$((failed + 1))
fi

# Test 5: Workflow service health
echo -n "5. Workflow service health... "
response=$(curl -sS "$BASE_URL:18109/egov-workflow-v2/health" 2>&1)
if echo "$response" | grep -q "UP"; then
  echo -e "\033[32mPASS\033[0m"
  passed=$((passed + 1))
else
  echo -e "\033[31mFAIL\033[0m"
  failed=$((failed + 1))
fi

# Test 6: Boundary-service health
echo -n "6. Boundary-service (v2) health... "
response=$(curl -sS "$BASE_URL:18081/boundary-service/actuator/health" 2>&1)
if echo "$response" | grep -q "UP"; then
  echo -e "\033[32mPASS\033[0m"
  passed=$((passed + 1))
else
  echo -e "\033[31mFAIL\033[0m"
  failed=$((failed + 1))
fi

# Test 7: Encryption service health
echo -n "7. Encryption service health... "
response=$(curl -sS "$BASE_URL:11234/egov-enc-service/actuator/health" 2>&1)
if echo "$response" | grep -q "UP"; then
  echo -e "\033[32mPASS\033[0m"
  passed=$((passed + 1))
else
  echo -e "\033[31mFAIL\033[0m"
  failed=$((failed + 1))
fi

# Test 8: Elasticsearch cluster
echo -n "8. Elasticsearch cluster... "
response=$(curl -sS "$BASE_URL:19200/_cluster/health" 2>&1)
if echo "$response" | grep -q "green\|yellow"; then
  echo -e "\033[32mPASS\033[0m"
  passed=$((passed + 1))
else
  echo -e "\033[31mFAIL\033[0m"
  failed=$((failed + 1))
fi

echo ""
echo "=== Summary: $passed passed, $failed failed ==="

if [[ $failed -eq 0 ]]; then
  exit 0
else
  exit 1
fi
