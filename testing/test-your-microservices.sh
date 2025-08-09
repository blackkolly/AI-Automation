#!/bin/bash

# =================================================================
# REAL TESTING SCRIPT FOR YOUR KUBERNETES MICROSERVICES PLATFORM
# =================================================================
#
# This script tests YOUR actual services:
# - API Gateway (localhost:30000)
# - Auth Service (localhost:30001)
# - Product Service (localhost:30002) 
# - Order Service (localhost:30003)
# - Frontend Dashboard (localhost:30080)
#
# =================================================================

echo "🚀 TESTING YOUR ACTUAL KUBERNETES MICROSERVICES PLATFORM"
echo "=========================================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TESTS=0

# YOUR actual service URLs
declare -A SERVICES=(
    ["API_GATEWAY"]="http://localhost:30000"
    ["AUTH_SERVICE"]="http://localhost:30001"
    ["PRODUCT_SERVICE"]="http://localhost:30002"
    ["ORDER_SERVICE"]="http://localhost:30003"
    ["FRONTEND"]="http://localhost:30080"
)

# Function to test service health
test_service_health() {
    local service_name="$1"
    local service_url="$2"
    
    echo -e "${BLUE}🔄 Testing: ${service_name} Health Check${NC}"
    
    if curl -s -f "${service_url}/health" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ PASSED: ${service_name} is healthy${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}❌ FAILED: ${service_name} is not responding${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

# Function to test service endpoints
test_service_endpoints() {
    local service_name="$1"
    local service_url="$2"
    
    case $service_name in
        "AUTH_SERVICE")
            echo -e "${BLUE}🔄 Testing: Auth Service Login Endpoint${NC}"
            
            local response=$(curl -s -w "%{http_code}" -X POST \
                -H "Content-Type: application/json" \
                -d '{"email":"test@example.com","password":"password123"}' \
                "${service_url}/auth/login" -o /dev/null)
            
            if [ "$response" = "200" ]; then
                echo -e "${GREEN}✅ PASSED: Auth Service login endpoint works${NC}"
                TESTS_PASSED=$((TESTS_PASSED + 1))
            else
                echo -e "${RED}❌ FAILED: Auth Service login endpoint (HTTP: $response)${NC}"
                TESTS_FAILED=$((TESTS_FAILED + 1))
            fi
            TOTAL_TESTS=$((TOTAL_TESTS + 1))
            ;;
            
        "PRODUCT_SERVICE")
            echo -e "${BLUE}🔄 Testing: Product Service Products List${NC}"
            
            local response=$(curl -s -w "%{http_code}" "${service_url}/products" -o /dev/null)
            
            if [ "$response" = "200" ]; then
                echo -e "${GREEN}✅ PASSED: Product Service products endpoint works${NC}"
                TESTS_PASSED=$((TESTS_PASSED + 1))
            else
                echo -e "${RED}❌ FAILED: Product Service products endpoint (HTTP: $response)${NC}"
                TESTS_FAILED=$((TESTS_FAILED + 1))
            fi
            TOTAL_TESTS=$((TOTAL_TESTS + 1))
            ;;
            
        "ORDER_SERVICE")
            echo -e "${BLUE}🔄 Testing: Order Service Orders List${NC}"
            
            local response=$(curl -s -w "%{http_code}" "${service_url}/orders" -o /dev/null)
            
            if [ "$response" = "200" ]; then
                echo -e "${GREEN}✅ PASSED: Order Service orders endpoint works${NC}"
                TESTS_PASSED=$((TESTS_PASSED + 1))
            else
                echo -e "${RED}❌ FAILED: Order Service orders endpoint (HTTP: $response)${NC}"
                TESTS_FAILED=$((TESTS_FAILED + 1))
            fi
            TOTAL_TESTS=$((TOTAL_TESTS + 1))
            ;;
            
        "API_GATEWAY")
            echo -e "${BLUE}🔄 Testing: API Gateway Status Endpoint${NC}"
            
            local response=$(curl -s -w "%{http_code}" "${service_url}/api/status" -o /dev/null)
            
            if [ "$response" = "200" ]; then
                echo -e "${GREEN}✅ PASSED: API Gateway status endpoint works${NC}"
                TESTS_PASSED=$((TESTS_PASSED + 1))
            else
                echo -e "${RED}❌ FAILED: API Gateway status endpoint (HTTP: $response)${NC}"
                TESTS_FAILED=$((TESTS_FAILED + 1))
            fi
            TOTAL_TESTS=$((TOTAL_TESTS + 1))
            ;;
            
        "FRONTEND")
            echo -e "${BLUE}🔄 Testing: Frontend Dashboard Access${NC}"
            
            local response=$(curl -s -w "%{http_code}" "${service_url}" -o /dev/null)
            
            if [ "$response" = "200" ]; then
                echo -e "${GREEN}✅ PASSED: Frontend dashboard is accessible${NC}"
                TESTS_PASSED=$((TESTS_PASSED + 1))
            else
                echo -e "${RED}❌ FAILED: Frontend dashboard (HTTP: $response)${NC}"
                TESTS_FAILED=$((TESTS_FAILED + 1))
            fi
            TOTAL_TESTS=$((TOTAL_TESTS + 1))
            ;;
    esac
}

# Function to test response times
test_response_times() {
    local service_name="$1"
    local service_url="$2"
    
    echo -e "${BLUE}🔄 Testing: ${service_name} Response Time${NC}"
    
    local response_time=$(curl -s -w "%{time_total}" "${service_url}/health" -o /dev/null)
    local response_ms=$(echo "$response_time * 1000" | bc)
    
    if (( $(echo "$response_time < 2.0" | bc -l) )); then
        echo -e "${GREEN}✅ PASSED: ${service_name} responds in ${response_ms}ms${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAILED: ${service_name} too slow (${response_ms}ms)${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

echo -e "${CYAN}Phase 1: Service Health Checks${NC}"
echo "==============================="
echo ""

# Test all YOUR services
for service_name in "${!SERVICES[@]}"; do
    service_url="${SERVICES[$service_name]}"
    test_service_health "$service_name" "$service_url"
    echo ""
done

echo -e "${CYAN}Phase 2: Endpoint Functionality Tests${NC}"
echo "======================================"
echo ""

# Test service endpoints
for service_name in "${!SERVICES[@]}"; do
    service_url="${SERVICES[$service_name]}"
    test_service_endpoints "$service_name" "$service_url"
    echo ""
done

echo -e "${CYAN}Phase 3: Performance Tests${NC}"
echo "=========================="
echo ""

# Test response times
for service_name in "${!SERVICES[@]}"; do
    service_url="${SERVICES[$service_name]}"
    test_response_times "$service_name" "$service_url"
    echo ""
done

echo -e "${CYAN}Phase 4: Integration Flow Test${NC}"
echo "==============================="
echo ""

echo -e "${BLUE}🔄 Testing: Complete User Flow${NC}"

# Test complete flow: Auth -> Products -> Orders
auth_token=""
flow_success=true

# Step 1: Login
echo "Step 1: Authenticating with Auth Service..."
auth_response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d '{"email":"test@example.com","password":"password123"}' \
    "${SERVICES[AUTH_SERVICE]}/auth/login")

if echo "$auth_response" | grep -q "token"; then
    echo "✅ Authentication successful"
    auth_token=$(echo "$auth_response" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
else
    echo "❌ Authentication failed"
    flow_success=false
fi

# Step 2: Get Products
echo "Step 2: Fetching products from Product Service..."
products_response=$(curl -s "${SERVICES[PRODUCT_SERVICE]}/products")

if echo "$products_response" | grep -q "id"; then
    echo "✅ Products retrieved successfully"
else
    echo "❌ Product retrieval failed"
    flow_success=false
fi

# Step 3: Get Orders
echo "Step 3: Fetching orders from Order Service..."
orders_response=$(curl -s "${SERVICES[ORDER_SERVICE]}/orders")

if echo "$orders_response" | grep -q "\["; then
    echo "✅ Orders retrieved successfully"
else
    echo "❌ Order retrieval failed"
    flow_success=false
fi

if [ "$flow_success" = true ]; then
    echo -e "${GREEN}✅ PASSED: Complete integration flow works${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}❌ FAILED: Integration flow incomplete${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

echo ""

# Run K6 performance test if available
echo -e "${CYAN}Phase 5: Load Testing (K6)${NC}"
echo "=========================="
echo ""

if command -v k6 &> /dev/null; then
    echo -e "${BLUE}🔄 Running: K6 Load Test on YOUR Services${NC}"
    
    if k6 run --duration 30s --vus 2 performance/load-tests/real-microservices-test.js; then
        echo -e "${GREEN}✅ PASSED: Load test completed${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAILED: Load test failed${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
else
    echo -e "${YELLOW}⚠️  K6 not installed - using Docker K6${NC}"
    
    if docker run --rm --network host -v $(pwd)/performance:/scripts grafana/k6 run --duration 30s --vus 2 /scripts/load-tests/real-microservices-test.js; then
        echo -e "${GREEN}✅ PASSED: Docker K6 load test completed${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAILED: Docker K6 load test failed${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
fi

echo ""

echo -e "${PURPLE}🎯 REAL TEST RESULTS FOR YOUR MICROSERVICES PLATFORM${NC}"
echo "====================================================="
echo ""
echo -e "${BLUE}📊 Test Statistics:${NC}"
echo -e "✅ Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "❌ Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo -e "📈 Success Rate: ${CYAN}$(echo "scale=1; $TESTS_PASSED * 100 / $TOTAL_TESTS" | bc -l)%${NC}"
echo ""

echo -e "${BLUE}🔗 YOUR Services Tested:${NC}"
for service_name in "${!SERVICES[@]}"; do
    echo "• $service_name: ${SERVICES[$service_name]}"
done
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 ALL TESTS PASSED! 🎉${NC}"
    echo -e "${GREEN}Your Kubernetes microservices platform is working perfectly!${NC}"
    echo ""
    echo -e "${CYAN}✨ Validated Components:${NC}"
    echo "• ✅ API Gateway - Health & routing"
    echo "• ✅ Auth Service - Authentication endpoints"
    echo "• ✅ Product Service - Product catalog endpoints"
    echo "• ✅ Order Service - Order management endpoints"
    echo "• ✅ Frontend Dashboard - User interface"
    echo "• ✅ Service Integration - Complete workflows"
    echo "• ✅ Performance - Response times & load testing"
    echo ""
    exit 0
else
    echo -e "${RED}⚠️ Some tests failed for your services.${NC}"
    echo -e "${YELLOW}💡 This might be because:${NC}"
    echo "• Services are not running (kubectl get pods)"
    echo "• Ports are not exposed correctly (kubectl get svc)"
    echo "• Services are starting up (check logs)"
    echo ""
    exit 1
fi
