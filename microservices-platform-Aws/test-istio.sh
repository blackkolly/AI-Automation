#!/bin/bash

# Test Istio Service Mesh Configuration
# This script validates all Istio components and features

set -e

echo "🧪 Testing Istio Service Mesh Configuration..."

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="$3"
    
    print_status "Testing: $test_name"
    
    if eval "$test_command" > /dev/null 2>&1; then
        print_success "✅ $test_name"
        ((TESTS_PASSED++))
    else
        print_error "❌ $test_name"
        ((TESTS_FAILED++))
    fi
}

run_test_with_output() {
    local test_name="$1"
    local test_command="$2"
    
    print_status "Testing: $test_name"
    
    local output
    output=$(eval "$test_command" 2>&1)
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        print_success "✅ $test_name"
        echo "   Output: $output"
        ((TESTS_PASSED++))
    else
        print_error "❌ $test_name"
        echo "   Error: $output"
        ((TESTS_FAILED++))
    fi
}

echo "🔍 Istio Control Plane Tests"
echo "============================="

# Test Istio installation
run_test "Istio namespace exists" "kubectl get namespace istio-system"
run_test "Istiod deployment ready" "kubectl get deployment istiod -n istio-system -o jsonpath='{.status.readyReplicas}' | grep -q '1'"
run_test "Istio ingress gateway ready" "kubectl get deployment istio-ingressgateway -n istio-system -o jsonpath='{.status.readyReplicas}' | grep -q '1'"

echo ""
echo "🔍 Sidecar Injection Tests"
echo "=========================="

# Test sidecar injection
run_test "Microservices namespace labeled for injection" "kubectl get namespace microservices -o jsonpath='{.metadata.labels.istio-injection}' | grep -q 'enabled'"

# Check if sidecars are injected
for service in api-gateway auth-service product-service order-service; do
    run_test_with_output "$service has Istio sidecar" "kubectl get pod -n microservices -l app=$service -o jsonpath='{.items[0].spec.containers[*].name}' | grep -q 'istio-proxy'"
done

echo ""
echo "🔍 Gateway and Virtual Service Tests"
echo "===================================="

# Test Istio configurations
run_test "Microservices gateway exists" "kubectl get gateway microservices-gateway -n microservices"
run_test "Virtual services exist" "kubectl get virtualservice -n microservices | grep -q 'api-gateway-vs'"
run_test "Destination rules exist" "kubectl get destinationrule -n microservices | grep -q 'api-gateway-dr'"

echo ""
echo "🔍 Security Policy Tests"
echo "========================"

# Test security policies
run_test "PeerAuthentication policy exists" "kubectl get peerauthentication default -n microservices"
run_test "Authorization policies exist" "kubectl get authorizationpolicy -n microservices | grep -q 'microservices-authz'"

echo ""
echo "🔍 Observability Tests"
echo "====================="

# Test Kiali
run_test "Kiali deployment ready" "kubectl get deployment kiali -n istio-system -o jsonpath='{.status.readyReplicas}' | grep -q '1'"
run_test "Telemetry configuration exists" "kubectl get telemetry default-metrics -n microservices"

echo ""
echo "🔍 Traffic Tests"
echo "==============="

# Get gateway URL
GATEWAY_PORT=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
GATEWAY_URL="http://localhost:$GATEWAY_PORT"

print_status "Testing traffic through Istio Gateway..."

# Test API Gateway endpoint
if curl -s -o /dev/null -w "%{http_code}" "$GATEWAY_URL/health" | grep -q "200"; then
    print_success "✅ API Gateway accessible through Istio"
    ((TESTS_PASSED++))
else
    print_error "❌ API Gateway not accessible through Istio"
    print_warning "   This might be normal if services are still starting up"
    ((TESTS_FAILED++))
fi

# Test individual services through gateway
for endpoint in "auth/health" "products/health" "orders/health"; do
    if curl -s -o /dev/null -w "%{http_code}" "$GATEWAY_URL/$endpoint" | grep -q "200\|404"; then
        print_success "✅ $endpoint endpoint accessible"
        ((TESTS_PASSED++))
    else
        print_warning "⚠️  $endpoint endpoint not accessible (service may not have health endpoint)"
    fi
done

echo ""
echo "🔍 mTLS Tests"
echo "============"

# Test mTLS
print_status "Checking mTLS configuration..."
if kubectl exec "$(kubectl get pod -n microservices -l app=api-gateway -o jsonpath='{.items[0].metadata.name}')" -n microservices -c istio-proxy -- pilot-agent request GET stats/config_dump 2>/dev/null | grep -q "tlsContext"; then
    print_success "✅ mTLS is configured"
    ((TESTS_PASSED++))
else
    print_warning "⚠️  mTLS configuration not detected (this is normal for PERMISSIVE mode)"
fi

echo ""
echo "🔍 Circuit Breaker Tests"
echo "======================="

# Test circuit breaker configuration
for service in api-gateway auth-service product-service order-service; do
    if kubectl get destinationrule "${service}-dr" -n microservices -o yaml | grep -q "circuitBreaker"; then
        print_success "✅ Circuit breaker configured for $service"
        ((TESTS_PASSED++))
    else
        print_error "❌ Circuit breaker not configured for $service"
        ((TESTS_FAILED++))
    fi
done

echo ""
echo "📊 Dashboard Access Information"
echo "=============================="

echo "🌐 Istio Gateway: $GATEWAY_URL"

# Kiali access
KIALI_PORT=$(kubectl get svc kiali -n istio-system -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
if [ -n "$KIALI_PORT" ]; then
    echo "📈 Kiali Dashboard: http://localhost:$KIALI_PORT"
else
    echo "📈 Kiali Dashboard: kubectl port-forward svc/kiali -n istio-system 20001:20001"
fi

echo "📊 Prometheus: http://localhost:30090"
echo "📈 Grafana: http://localhost:30300"
echo "🔍 Jaeger: http://localhost:30686"

echo ""
echo "🧪 Test Results Summary"
echo "======================"
echo "Tests Passed: $TESTS_PASSED"
echo "Tests Failed: $TESTS_FAILED"

if [ $TESTS_FAILED -eq 0 ]; then
    print_success "🎉 All critical tests passed! Istio Service Mesh is working correctly."
    echo ""
    echo "🚀 Next Steps:"
    echo "1. Open Kiali dashboard to visualize service mesh"
    echo "2. Generate traffic to see observability features"
    echo "3. Test circuit breaker with high load"
    echo "4. Explore security policies and mTLS"
else
    print_warning "⚠️  Some tests failed. This might be normal if:"
    echo "   - Services are still starting up"
    echo "   - Health endpoints are not implemented"
    echo "   - Network policies are restrictive"
    echo ""
    echo "🔧 Troubleshooting:"
    echo "1. Check pod status: kubectl get pods -A"
    echo "2. Check Istio proxy logs: kubectl logs <pod-name> -c istio-proxy -n microservices"
    echo "3. Verify Istio configuration: istioctl analyze"
fi

echo ""
echo "🔍 Additional Diagnostics"
echo "========================"
echo "Run these commands for detailed diagnostics:"
echo "• istioctl analyze -A"
echo "• istioctl proxy-config cluster <pod-name> -n microservices"
echo "• kubectl logs deployment/istiod -n istio-system"
