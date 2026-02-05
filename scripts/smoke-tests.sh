#!/bin/bash
# Smoke tests for DIGIT core services (CI version)
# Related: https://github.com/subhashini-egov/digit-2.9lts-core-storm/issues/6

BASE_URL="${1:-http://0.0.0.0}"

echo "=== DIGIT Core Services Smoke Tests ==="
echo "Base URL: $BASE_URL"
echo ""

passed=0
failed=0

test_result() {
  if [ "$1" = "pass" ]; then
    echo -e "\033[32mPASS\033[0m"
    passed=$((passed + 1))
  else
    echo -e "\033[31mFAIL\033[0m"
    failed=$((failed + 1))
  fi
}

# ==== Health Checks ====
echo "--- Health Checks ---"

echo -n "1. MDMS service health... "
response=$(curl -sS "$BASE_URL:18094/mdms-v2/health" 2>&1)
echo "$response" | grep -q "UP" && test_result pass || test_result fail

echo -n "2. User service health... "
response=$(curl -sS "$BASE_URL:18107/user/health" 2>&1)
echo "$response" | grep -q "UP" && test_result pass || test_result fail

echo -n "3. Workflow service health... "
response=$(curl -sS "$BASE_URL:18109/egov-workflow-v2/health" 2>&1)
echo "$response" | grep -q "UP" && test_result pass || test_result fail

echo -n "4. IDGen service health... "
response=$(curl -sS "$BASE_URL:18088/egov-idgen/health" 2>&1)
echo "$response" | grep -q "UP" && test_result pass || test_result fail

echo -n "5. Localization service health... "
response=$(curl -sS "$BASE_URL:18096/localization/actuator/health" 2>&1)
echo "$response" | grep -q "UP" && test_result pass || test_result fail

echo -n "6. Encryption service health... "
response=$(curl -sS "$BASE_URL:11234/egov-enc-service/actuator/health" 2>&1)
echo "$response" | grep -q "UP" && test_result pass || test_result fail

echo -n "7. Access Control health... "
response=$(curl -sS "$BASE_URL:18090/access/health" 2>&1)
echo "$response" | grep -q "UP" && test_result pass || test_result fail

echo -n "8. Location service health... "
response=$(curl -sS "$BASE_URL:18084/egov-location/health" 2>&1)
echo "$response" | grep -q "UP" && test_result pass || test_result fail

echo -n "9. Boundary service health... "
response=$(curl -sS "$BASE_URL:18081/boundary-service/actuator/health" 2>&1)
echo "$response" | grep -q "UP" && test_result pass || test_result fail

echo -n "10. PGR service health... "
response=$(curl -sS "$BASE_URL:18083/pgr-services/health" 2>&1)
echo "$response" | grep -q "UP" && test_result pass || test_result fail

echo -n "11. Elasticsearch cluster... "
response=$(curl -sS "$BASE_URL:19200/_cluster/health" 2>&1)
echo "$response" | grep -q "green\|yellow" && test_result pass || test_result fail

echo ""

# ==== API Tests ====
echo "--- API Tests ---"

# MDMS - Fetch tenants
echo -n "12. MDMS search tenants... "
response=$(curl -sS -X POST "$BASE_URL:18094/mdms-v2/v2/_search" \
  -H 'Content-Type: application/json' \
  -d '{"RequestInfo":{"apiId":"digit","ver":"1.0","ts":0},"MdmsCriteria":{"tenantId":"pg","schemaCode":"tenant.tenants"}}' 2>&1)
if echo "$response" | jq -e '.mdms | length > 0' > /dev/null 2>&1; then
  test_result pass
else
  test_result fail
fi

# User - Create test user
echo -n "13. User creation... "
response=$(curl -sS -X POST "$BASE_URL:18107/user/users/_createnovalidate" \
  -H 'Content-Type: application/json' \
  -d '{
    "RequestInfo":{"apiId":"Rainmaker","ver":".01","action":"_create","msgId":"test"},
    "User":{"userName":"ci-test","name":"CI Test User","gender":"MALE","mobileNumber":"9999977777","active":true,"type":"EMPLOYEE","tenantId":"pg.citya","password":"eGov@123","roles":[{"code":"EMPLOYEE","name":"Employee","tenantId":"pg.citya"}]}
  }' 2>&1)
if echo "$response" | jq -e '.user[0].uuid' > /dev/null 2>&1; then
  test_result pass
elif echo "$response" | grep -q "DuplicateUserName"; then
  test_result pass  # User already exists is OK
else
  test_result fail
fi

# User - Login
echo -n "14. User login... "
response=$(curl -sS -X POST "$BASE_URL:18107/user/oauth/token" \
  -H "authorization: Basic ZWdvdi11c2VyLWNsaWVudDo=" \
  -H "content-type: application/x-www-form-urlencoded" \
  --data-raw "username=ci-test&password=eGov%40123&userType=EMPLOYEE&tenantId=pg.citya&scope=read&grant_type=password" 2>&1)
if echo "$response" | jq -e '.access_token' > /dev/null 2>&1; then
  test_result pass
else
  test_result fail
fi

# IDGen - Generate ID
echo -n "15. IDGen generate... "
response=$(curl -sS -X POST "$BASE_URL:18088/egov-idgen/id/_generate" \
  -H 'Content-Type: application/json' \
  -d '{
    "RequestInfo":{"apiId":"Rainmaker","ver":".01","action":"_generate","msgId":"test"},
    "idRequests":[{"idName":"ci.test.id","tenantId":"pg.citya","format":"CI/TEST/[SEQ_CI_TEST]"}]
  }' 2>&1)
if echo "$response" | jq -e '.idResponses[0].id' > /dev/null 2>&1; then
  test_result pass
else
  test_result fail
fi

# Localization - Search
echo -n "16. Localization search... "
response=$(curl -sS -X POST "$BASE_URL:18096/localization/messages/v1/_search?locale=en_IN&tenantId=pg&module=rainmaker-common" \
  -H 'Content-Type: application/json' \
  -d '{"RequestInfo":{"apiId":"Rainmaker","ver":".01","action":"_search","msgId":"test"}}' 2>&1)
if echo "$response" | jq -e '.messages' > /dev/null 2>&1; then
  test_result pass
else
  test_result fail
fi

# Kong Gateway - Check routing
echo -n "17. Kong Gateway routing... "
response=$(curl -sS "$BASE_URL:18000/user/health" 2>&1)
echo "$response" | grep -q "UP" && test_result pass || test_result fail

echo ""
echo "=== Summary: $passed passed, $failed failed ==="

if [[ $failed -eq 0 ]]; then
  exit 0
else
  exit 1
fi
