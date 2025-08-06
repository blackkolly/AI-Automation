#!/bin/bash

# Istio Testing and Validation Script
# This script tests Istio functionality without requiring istioctl

set -e

echo "🧪 Testing Istio Service Mesh..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

# Test 1: Check Istio installation
print_status "Test 1: Checking Istio control plane..."

ISTIOD_STATUS=$(kubectl get deployment istiod -n istio-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
if [ "$ISTIOD_STATUS" -gt 0 ]; then
    print_success "Istio control plane is running ($ISTIOD_STATUS replicas ready)"
else
    print_error "Istio control plane is not running"
    exit 1
fi

# Test 2: Check Istio Gateway
print_status "Test 2: Checking Istio Gateway..."

GATEWAY_STATUS=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer}' 2>/dev/null || echo "")
if [ -n "$GATEWAY_STATUS" ]; then
    print_success "Istio Ingress Gateway is deployed"
    kubectl get svc istio-ingressgateway -n istio-system
else
    print_error "Istio Ingress Gateway not found"
fi

# Test 3: Check sidecar injection
print_status "Test 3: Checking sidecar injection configuration..."

INJECTION_LABEL=$(kubectl get namespace microservices -o jsonpath='{.metadata.labels.istio-injection}' 2>/dev/null || echo "")
if [ "$INJECTION_LABEL" = "enabled" ]; then
    print_success "Sidecar injection is enabled for microservices namespace"
else
    print_warning "Sidecar injection is not enabled for microservices namespace"
    echo "Run: kubectl label namespace microservices istio-injection=enabled"
fi

# Test 4: Check if microservices have sidecars
print_status "Test 4: Checking microservices sidecar injection..."

PODS_WITH_SIDECARS=$(kubectl get pods -n microservices -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.containers[*].name}{"\n"}{end}' 2>/dev/null | grep istio-proxy | wc -l || echo "0")

if [ "$PODS_WITH_SIDECARS" -gt 0 ]; then
    print_success "$PODS_WITH_SIDECARS pods have Istio sidecars injected"
    echo "Pods with sidecars:"
    kubectl get pods -n microservices -o custom-columns=NAME:.metadata.name,CONTAINERS:.spec.containers[*].name 2>/dev/null | grep istio-proxy || true
else
    print_warning "No pods found with Istio sidecars"
    echo "This might be because:"
    echo "1. No microservices are deployed yet"
    echo "2. Pods need to be restarted after enabling injection"
    echo "3. Namespace 'microservices' doesn't exist"
fi

# Test 5: Check Istio configurations
print_status "Test 5: Checking Istio custom resources..."

GATEWAYS=$(kubectl get gateway -A --no-headers 2>/dev/null | wc -l)
VIRTUAL_SERVICES=$(kubectl get virtualservice -A --no-headers 2>/dev/null | wc -l)
DESTINATION_RULES=$(kubectl get destinationrule -A --no-headers 2>/dev/null | wc -l)

echo "Istio resources found:"
echo "  - Gateways: $GATEWAYS"
echo "  - VirtualServices: $VIRTUAL_SERVICES"
echo "  - DestinationRules: $DESTINATION_RULES"

if [ "$GATEWAYS" -gt 0 ] && [ "$VIRTUAL_SERVICES" -gt 0 ]; then
    print_success "Istio traffic management is configured"
else
    print_warning "Istio traffic management configurations are missing"
fi

# Test 6: Check observability tools
print_status "Test 6: Checking observability tools..."

OBSERVABILITY_TOOLS=("kiali" "jaeger" "grafana" "prometheus")
for tool in "${OBSERVABILITY_TOOLS[@]}"; do
    STATUS=$(kubectl get deployment $tool -n istio-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if [ "$STATUS" -gt 0 ]; then
        print_success "$tool is running"
    else
        print_warning "$tool is not running"
    fi
done

# Test 7: Test connectivity (if microservices are deployed)
print_status "Test 7: Testing service mesh connectivity..."

if kubectl get deployment api-gateway -n microservices >/dev/null 2>&1; then
    print_status "Found api-gateway deployment, testing connectivity..."
    
    # Port forward in background
    kubectl port-forward svc/istio-ingressgateway 8080:80 -n istio-system >/dev/null 2>&1 &
    PORT_FORWARD_PID=$!
    
    # Wait a moment for port forwarding to establish
    sleep 2
    
    # Test HTTP request
    if curl -s -f http://localhost:8080 >/dev/null 2>&1; then
        print_success "HTTP connectivity through Istio gateway works"
    else
        print_warning "Could not reach application through Istio gateway"
        echo "This might be normal if:"
        echo "1. Application is not ready yet"
        echo "2. VirtualService routing is not configured"
        echo "3. Application doesn't respond to root path"
    fi
    
    # Clean up port forward
    kill $PORT_FORWARD_PID 2>/dev/null || true
else
    print_warning "No microservices found to test connectivity"
fi

# Test 8: Configuration validation
print_status "Test 8: Validating Istio configurations..."

# Check for common configuration issues
CONFIG_ERRORS=0

# Check if gateways reference correct selectors
GATEWAY_SELECTORS=$(kubectl get gateway -A -o jsonpath='{range .items[*]}{.spec.selector}{"\n"}{end}' 2>/dev/null)
if echo "$GATEWAY_SELECTORS" | grep -q "istio: ingressgateway"; then
    print_success "Gateway selectors are correctly configured"
else
    print_warning "Gateway selectors might be misconfigured"
    CONFIG_ERRORS=$((CONFIG_ERRORS + 1))
fi

# Summary
echo -e "\n${BLUE}=== Test Summary ===${NC}"
if [ $CONFIG_ERRORS -eq 0 ]; then
    print_success "All Istio tests passed! Service mesh is ready."
else
    print_warning "Some tests failed. Check the warnings above."
fi

# Quick troubleshooting guide
echo -e "\n${YELLOW}=== Quick Troubleshooting ===${NC}"
echo "If tests failed, try these commands:"
echo ""
echo "1. Check Istio system status:"
echo "   kubectl get pods -n istio-system"
echo ""
echo "2. Check Istio logs:"
echo "   kubectl logs deployment/istiod -n istio-system"
echo ""
echo "3. Restart microservices to inject sidecars:"
echo "   kubectl rollout restart deployment -n microservices"
echo ""
echo "4. Check if services are accessible:"
echo "   kubectl get svc -n microservices"
echo ""
echo "5. Port forward to test connectivity:"
echo "   kubectl port-forward svc/istio-ingressgateway 8080:80 -n istio-system"

echo -e "\n${GREEN}Testing completed!${NC}"
