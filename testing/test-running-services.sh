#!/bin/bash

# =================================================================
# TESTING YOUR RUNNING KUBERNETES MICROSERVICES
# =================================================================
# Testing services in the 'microservices' namespace
# =================================================================

echo "🚀 TESTING YOUR RUNNING MICROSERVICES PLATFORM"
echo "==============================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0

echo -e "${BLUE}📋 Checking Kubernetes Service Status${NC}"
echo "========================================="
echo ""

# Check services in microservices namespace
echo "🔍 Services in microservices namespace:"
kubectl get svc -n microservices
echo ""

echo "🔍 Pods in microservices namespace:"
kubectl get pods -n microservices
echo ""

echo -e "${BLUE}🧪 Testing Service Endpoints via Port Forward${NC}"
echo "================================================"
echo ""

# Test API Gateway via kubectl proxy
echo "🔄 Testing API Gateway (port-forward)..."
kubectl port-forward -n microservices svc/api-gateway 8000:3000 &
PORT_FORWARD_PID=$!
sleep 3

if curl -s -f http://localhost:8000/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ API Gateway health check PASSED${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}❌ API Gateway health check FAILED${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Kill port forward
kill $PORT_FORWARD_PID 2>/dev/null

echo ""

# Test Auth Service
echo "🔄 Testing Auth Service (port-forward)..."
kubectl port-forward -n microservices svc/auth-service 8001:3001 &
PORT_FORWARD_PID=$!
sleep 3

if curl -s -f http://localhost:8001/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Auth Service health check PASSED${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}❌ Auth Service health check FAILED${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

kill $PORT_FORWARD_PID 2>/dev/null

echo ""

# Test Frontend
echo "🔄 Testing Frontend (port-forward)..."
kubectl port-forward -n microservices svc/frontend 8080:80 &
PORT_FORWARD_PID=$!
sleep 3

if curl -s -f http://localhost:8080 >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Frontend access PASSED${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}❌ Frontend access FAILED${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

kill $PORT_FORWARD_PID 2>/dev/null

echo ""

# Test Order Service
echo "🔄 Testing Order Service (port-forward)..."
kubectl port-forward -n microservices svc/order-service 8003:3003 &
PORT_FORWARD_PID=$!
sleep 3

if curl -s -f http://localhost:8003/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Order Service health check PASSED${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}❌ Order Service health check FAILED${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

kill $PORT_FORWARD_PID 2>/dev/null

echo ""

# Test direct NodePort access (if accessible)
echo -e "${BLUE}🌐 Testing NodePort Access${NC}"
echo "==========================="
echo ""

# Try different approaches for NodePort access
echo "🔄 Testing API Gateway via NodePort (localhost:30000)..."
if timeout 5 curl -s -f http://localhost:30000/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ NodePort API Gateway ACCESSIBLE${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}⚠️ NodePort API Gateway not accessible via localhost${NC}"
    # Try via node IP
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    if timeout 5 curl -s -f http://$NODE_IP:30000/health >/dev/null 2>&1; then
        echo -e "${GREEN}✅ NodePort API Gateway accessible via node IP${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ NodePort API Gateway not accessible${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
fi

echo ""

echo -e "${BLUE}📊 Service Logs Check${NC}"
echo "===================="
echo ""

echo "📋 API Gateway recent logs:"
kubectl logs -n microservices deployment/api-gateway --tail=3
echo ""

echo "📋 Auth Service recent logs:"
kubectl logs -n microservices deployment/auth-service --tail=3
echo ""

echo "📋 Frontend recent logs:"
kubectl logs -n microservices deployment/frontend --tail=3
echo ""

echo -e "${BLUE}🎯 TEST RESULTS SUMMARY${NC}"
echo "======================="
echo ""
echo -e "✅ Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "❌ Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_PASSED -gt $TESTS_FAILED ]; then
    echo -e "${GREEN}🎉 Most services are working! 🎉${NC}"
    echo ""
    echo -e "${BLUE}💡 To access your services:${NC}"
    echo "• API Gateway: kubectl port-forward -n microservices svc/api-gateway 8000:3000"
    echo "• Auth Service: kubectl port-forward -n microservices svc/auth-service 8001:3001"
    echo "• Frontend: kubectl port-forward -n microservices svc/frontend 8080:80"
    echo "• Order Service: kubectl port-forward -n microservices svc/order-service 8003:3003"
    echo ""
    echo -e "${BLUE}🔗 Then access via:${NC}"
    echo "• http://localhost:8000/health (API Gateway)"
    echo "• http://localhost:8001/health (Auth Service)"
    echo "• http://localhost:8080 (Frontend Dashboard)"
    echo "• http://localhost:8003/health (Order Service)"
else
    echo -e "${RED}⚠️ Some services need attention.${NC}"
    echo ""
    echo -e "${YELLOW}💡 Troubleshooting steps:${NC}"
    echo "• Check pod logs: kubectl logs -n microservices <pod-name>"
    echo "• Check service status: kubectl get svc -n microservices"
    echo "• Check pod status: kubectl get pods -n microservices"
fi

echo ""
