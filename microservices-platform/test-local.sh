#!/bin/bash

# Local Platform Testing Script
# This script tests all components of the locally deployed platform

echo "🧪 Testing Local Microservices Platform"
echo "======================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

test_service() {
    local service_name=$1
    local url=$2
    local expected_status=${3:-200}
    
    print_status "Testing $service_name..."
    
    response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)
    
    if [ "$response" = "$expected_status" ]; then
        print_success "$service_name is responding (HTTP $response)"
        return 0
    else
        print_error "$service_name is not responding (HTTP $response)"
        return 1
    fi
}

test_json_endpoint() {
    local service_name=$1
    local url=$2
    
    print_status "Testing $service_name JSON response..."
    
    response=$(curl -s "$url" 2>/dev/null)
    
    if echo "$response" | jq . >/dev/null 2>&1; then
        print_success "$service_name returned valid JSON"
        echo "   Response: $(echo "$response" | jq -c '.')"
        return 0
    else
        print_error "$service_name returned invalid JSON"
        echo "   Response: $response"
        return 1
    fi
}

# Wait for services to be ready
print_status "Waiting for services to be ready..."
sleep 10

# Test infrastructure services
echo ""
echo "🔧 Testing Infrastructure Services"
echo "=================================="

test_service "Grafana" "http://localhost:30300/api/health"
test_service "Prometheus" "http://localhost:30090/-/healthy"
test_service "AlertManager" "http://localhost:30903/-/healthy"
test_service "Jaeger UI" "http://localhost:30686/"

# Test microservices
echo ""
echo "🚀 Testing Microservices"
echo "========================"

test_json_endpoint "API Gateway Health" "http://localhost:30000/health"
test_json_endpoint "API Gateway Status" "http://localhost:30000/api/status"
test_json_endpoint "Auth Service Health" "http://localhost:30001/health"
test_json_endpoint "Product Service Health" "http://localhost:30002/health"
test_json_endpoint "Product Service Products" "http://localhost:30002/products"
test_json_endpoint "Order Service Health" "http://localhost:30003/health"
test_json_endpoint "Order Service Orders" "http://localhost:30003/orders"

# Test metrics endpoints
echo ""
echo "📊 Testing Metrics Endpoints"
echo "============================"

test_service "API Gateway Metrics" "http://localhost:30000/metrics"
test_service "Auth Service Metrics" "http://localhost:30001/metrics"
test_service "Product Service Metrics" "http://localhost:30002/metrics"
test_service "Order Service Metrics" "http://localhost:30003/metrics"

# Test Prometheus targets
echo ""
echo "🎯 Testing Prometheus Service Discovery"
echo "======================================"

print_status "Checking Prometheus targets..."
targets_response=$(curl -s "http://localhost:30090/api/v1/targets" 2>/dev/null)

if echo "$targets_response" | jq . >/dev/null 2>&1; then
    active_targets=$(echo "$targets_response" | jq '.data.activeTargets | length')
    print_success "Prometheus has $active_targets active targets"
    
    # Check for our microservices
    microservices=(api-gateway auth-service product-service order-service)
    for service in "${microservices[@]}"; do
        if echo "$targets_response" | jq -r '.data.activeTargets[].labels.job' | grep -q "$service"; then
            print_success "Found $service in Prometheus targets"
        else
            print_warning "$service not found in Prometheus targets"
        fi
    done
else
    print_error "Failed to get Prometheus targets"
fi

# Check pod status
echo ""
echo "🏃 Pod Status Check"
echo "=================="

print_status "Checking pod status in microservices namespace..."
kubectl get pods -n microservices

print_status "Checking pod status in monitoring namespace..."
kubectl get pods -n monitoring

print_status "Checking pod status in observability namespace..."
kubectl get pods -n observability

# Generate some test traffic
echo ""
echo "🚦 Generating Test Traffic"
echo "========================="

print_status "Generating sample requests to create metrics..."

for i in {1..5}; do
    curl -s "http://localhost:30000/health" > /dev/null
    curl -s "http://localhost:30002/products" > /dev/null
    curl -s "http://localhost:30003/orders" > /dev/null
    sleep 1
done

print_success "Test traffic generated"

# Final summary
echo ""
echo "📋 Summary"
echo "=========="
echo ""
echo "✅ Local microservices platform testing completed!"
echo ""
echo "🌐 Quick access links:"
echo "├── Grafana:      http://localhost:30300 (admin / prom-operator)"
echo "├── Prometheus:   http://localhost:30090"
echo "├── Jaeger UI:    http://localhost:30686"
echo "└── API Gateway:  http://localhost:30000"
echo ""
echo "📊 To view metrics in Grafana:"
echo "1. Go to http://localhost:30300"
echo "2. Login with admin / prom-operator"
echo "3. Navigate to Dashboards"
echo "4. Look for Kubernetes and Node Exporter dashboards"
echo ""
echo "🔍 To view traces in Jaeger:"
echo "1. Go to http://localhost:30686"
echo "2. Select a service from the dropdown"
echo "3. Click 'Find Traces'"
echo ""
echo "🎯 To view Prometheus targets:"
echo "1. Go to http://localhost:30090"
echo "2. Navigate to Status → Targets"
echo "3. Check that all microservices are UP"
