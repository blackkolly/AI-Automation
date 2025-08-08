#!/bin/bash

# Product & Order Services Detailed Status Check
# Based on current Istio service mesh implementation

echo "🔍 PRODUCT & ORDER SERVICES - DETAILED STATUS CHECK"
echo "=================================================="
echo ""

# Function definitions for colored output
print_header() { echo -e "\n\033[0;36m=== $1 ===\033[0m"; }
print_success() { echo -e "\033[0;32m[✅ PASS]\033[0m $1"; }
print_warning() { echo -e "\033[1;33m[⚠️  WARN]\033[0m $1"; }
print_error() { echo -e "\033[0;31m[❌ FAIL]\033[0m $1"; }
print_info() { echo -e "\033[0;34m[ℹ️  INFO]\033[0m $1"; }

# 1. Pod Status Check
print_header "1. Pod Status Check"
echo "Product Service Pods:"
kubectl get pods -n microservices -l app=product-service -o wide 2>/dev/null || print_error "No product-service pods found"

echo -e "\nOrder Service Pods:"
kubectl get pods -n microservices -l app=order-service -o wide 2>/dev/null || print_error "No order-service pods found"

# 2. Service Status
print_header "2. Kubernetes Services"
echo "Product Service:"
kubectl get svc -n microservices product-service 2>/dev/null || print_error "Product service not found"

echo -e "\nOrder Service:"
kubectl get svc -n microservices order-service 2>/dev/null || print_error "Order service not found"

# 3. Check if services are running
print_header "3. Service Health Check"

# Check product service containers
PRODUCT_PODS=$(kubectl get pods -n microservices -l app=product-service -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
if [ -n "$PRODUCT_PODS" ]; then
    for pod in $PRODUCT_PODS; do
        STATUS=$(kubectl get pod $pod -n microservices -o jsonpath='{.status.phase}' 2>/dev/null)
        READY=$(kubectl get pod $pod -n microservices -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null)
        SIDECAR=$(kubectl get pod $pod -n microservices -o jsonpath='{.spec.containers[*].name}' 2>/dev/null | grep -q istio-proxy && echo "Yes" || echo "No")
        
        if [ "$STATUS" = "Running" ] && [ "$READY" = "true" ]; then
            print_success "Product Service pod $pod: Running (Sidecar: $SIDECAR)"
        else
            print_warning "Product Service pod $pod: Status=$STATUS, Ready=$READY"
        fi
    done
else
    print_error "No Product Service pods found"
fi

# Check order service containers
ORDER_PODS=$(kubectl get pods -n microservices -l app=order-service -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
if [ -n "$ORDER_PODS" ]; then
    for pod in $ORDER_PODS; do
        STATUS=$(kubectl get pod $pod -n microservices -o jsonpath='{.status.phase}' 2>/dev/null)
        READY=$(kubectl get pod $pod -n microservices -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null)
        SIDECAR=$(kubectl get pod $pod -n microservices -o jsonpath='{.spec.containers[*].name}' 2>/dev/null | grep -q istio-proxy && echo "Yes" || echo "No")
        
        if [ "$STATUS" = "Running" ] && [ "$READY" = "true" ]; then
            print_success "Order Service pod $pod: Running (Sidecar: $SIDECAR)"
        else
            print_warning "Order Service pod $pod: Status=$STATUS, Ready=$READY"
        fi
    done
else
    print_error "No Order Service pods found"
fi

# 4. Direct Service Testing
print_header "4. Direct Service Connectivity Test"

# Test if we can reach services directly
print_info "Testing Product Service (port 3002)..."
if kubectl exec -n microservices deployment/api-gateway -- curl -s -f -m 5 product-service:3002/products >/dev/null 2>&1; then
    PRODUCT_RESPONSE=$(kubectl exec -n microservices deployment/api-gateway -- curl -s product-service:3002/products 2>/dev/null | head -c 100)
    print_success "Product Service responding: ${PRODUCT_RESPONSE}..."
else
    print_warning "Product Service not responding on port 3002"
fi

print_info "Testing Order Service (port 3003)..."
if kubectl exec -n microservices deployment/api-gateway -- curl -s -f -m 5 order-service:3003/orders >/dev/null 2>&1; then
    ORDER_RESPONSE=$(kubectl exec -n microservices deployment/api-gateway -- curl -s order-service:3003/orders 2>/dev/null | head -c 100)
    print_success "Order Service responding: ${ORDER_RESPONSE}..."
else
    print_warning "Order Service not responding on port 3003"
fi

# 5. Istio Gateway Testing
print_header "5. Istio Gateway Access Test"

# Get the NodePort for testing
GATEWAY_PORT=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}' 2>/dev/null)

if [ -n "$GATEWAY_PORT" ]; then
    print_info "Istio Gateway NodePort: $GATEWAY_PORT"
    
    print_info "Testing Product Service via Istio Gateway..."
    PRODUCT_GATEWAY_RESPONSE=$(curl -s -w "HTTP:%{http_code}" "http://localhost:$GATEWAY_PORT/api/products" 2>/dev/null)
    HTTP_CODE=$(echo "$PRODUCT_GATEWAY_RESPONSE" | grep -o "HTTP:[0-9]*" | cut -d: -f2)
    CONTENT=$(echo "$PRODUCT_GATEWAY_RESPONSE" | sed 's/HTTP:[0-9]*$//')
    
    if [ "$HTTP_CODE" = "200" ]; then
        print_success "Product Service via Gateway: HTTP 200 - ${CONTENT:0:50}..."
    else
        print_warning "Product Service via Gateway: HTTP $HTTP_CODE"
    fi
    
    print_info "Testing Order Service via Istio Gateway..."
    ORDER_GATEWAY_RESPONSE=$(curl -s -w "HTTP:%{http_code}" "http://localhost:$GATEWAY_PORT/api/orders" 2>/dev/null)
    HTTP_CODE=$(echo "$ORDER_GATEWAY_RESPONSE" | grep -o "HTTP:[0-9]*" | cut -d: -f2)
    CONTENT=$(echo "$ORDER_GATEWAY_RESPONSE" | sed 's/HTTP:[0-9]*$//')
    
    if [ "$HTTP_CODE" = "200" ]; then
        print_success "Order Service via Gateway: HTTP 200 - ${CONTENT:0:50}..."
    else
        print_warning "Order Service via Gateway: HTTP $HTTP_CODE"
    fi
else
    print_error "Could not determine Istio Gateway port"
fi

# 6. Istio Configuration Check
print_header "6. Istio Configuration Status"

echo "VirtualServices for Product & Order:"
kubectl get virtualservice -n microservices -o custom-columns=NAME:.metadata.name,HOSTS:.spec.hosts --no-headers 2>/dev/null | grep -E "(product|order)" || print_warning "No VirtualServices found"

echo -e "\nDestinationRules for Product & Order:"
kubectl get destinationrule -n microservices -o custom-columns=NAME:.metadata.name,HOST:.spec.host --no-headers 2>/dev/null | grep -E "(product|order)" || print_warning "No DestinationRules found"

# 7. Service Logs Check
print_header "7. Recent Service Logs"

print_info "Product Service recent logs:"
kubectl logs -n microservices -l app=product-service --tail=3 2>/dev/null || print_warning "No product service logs available"

print_info "Order Service recent logs:"
kubectl logs -n microservices -l app=order-service --tail=3 2>/dev/null || print_warning "No order service logs available"

# 8. Database Connectivity (if applicable)
print_header "8. Database Connectivity"

print_info "Testing PostgreSQL connectivity for Product Service..."
if kubectl exec -n microservices deployment/api-gateway -- curl -s -f -m 5 product-service:3002/health >/dev/null 2>&1; then
    print_success "Product Service health check passed (database likely connected)"
else
    print_warning "Product Service health check failed"
fi

print_info "Testing database connectivity for Order Service..."
if kubectl exec -n microservices deployment/api-gateway -- curl -s -f -m 5 order-service:3003/health >/dev/null 2>&1; then
    print_success "Order Service health check passed"
else
    print_warning "Order Service health check failed"
fi

# Summary
print_header "9. Summary"

# Count running pods
PRODUCT_RUNNING=$(kubectl get pods -n microservices -l app=product-service --no-headers 2>/dev/null | grep -c "Running" || echo "0")
ORDER_RUNNING=$(kubectl get pods -n microservices -l app=order-service --no-headers 2>/dev/null | grep -c "Running" || echo "0")

echo "Service Status Summary:"
echo "  Product Service: $PRODUCT_RUNNING pod(s) running"
echo "  Order Service: $ORDER_RUNNING pod(s) running"

if [ "$PRODUCT_RUNNING" -gt 0 ] && [ "$ORDER_RUNNING" -gt 0 ]; then
    print_success "Both services are operational! ✅"
else
    print_warning "One or both services may have issues ⚠️"
fi

echo ""
echo "🌐 Quick Test Commands:"
echo "  curl http://localhost:$GATEWAY_PORT/api/products"
echo "  curl http://localhost:$GATEWAY_PORT/api/orders"
echo ""
print_info "Product & Order Services check completed!"
