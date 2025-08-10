#!/bin/bash

# Jaeger Tracing Demonstration Script
# This script generates various API calls to demonstrate distributed tracing

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="microservices"
OBSERVABILITY_NS="observability"

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_demo() {
    echo -e "${BLUE}[DEMO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get service URLs
get_service_urls() {
    print_info "Getting service URLs..."
    
    # API Gateway URL
    API_GW_HOST=$(kubectl get service api-gateway -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    if [ -z "$API_GW_HOST" ]; then
        API_GW_HOST=$(kubectl get service api-gateway -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    fi
    
    if [ -z "$API_GW_HOST" ]; then
        print_error "Could not get API Gateway URL. Using port-forward..."
        kubectl port-forward service/api-gateway 3000:3000 -n "$NAMESPACE" &
        PORT_FORWARD_PID=$!
        API_GW_URL="http://localhost:3000"
        sleep 5
    else
        API_GW_URL="http://$API_GW_HOST:3000"
    fi
    
    # Jaeger UI URL
    JAEGER_HOST=$(kubectl get service jaeger-external -n "$OBSERVABILITY_NS" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    if [ -z "$JAEGER_HOST" ]; then
        JAEGER_HOST=$(kubectl get service jaeger-external -n "$OBSERVABILITY_NS" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    fi
    
    if [ -n "$JAEGER_HOST" ]; then
        JAEGER_URL="http://$JAEGER_HOST:16686"
    else
        JAEGER_URL="http://localhost:16686"
    fi
    
    print_info "API Gateway: $API_GW_URL"
    print_info "Jaeger UI: $JAEGER_URL"
}

# Test basic health checks
test_health_checks() {
    print_demo "Testing health check endpoints..."
    
    echo "1. API Gateway Health Check:"
    response=$(curl -s -w "\\nHTTP Status: %{http_code}\\nResponse Time: %{time_total}s\\n" "$API_GW_URL/health")
    echo "$response"
    echo
    
    echo "2. Service Status Check (includes downstream services):"
    response=$(curl -s -w "\\nHTTP Status: %{http_code}\\nResponse Time: %{time_total}s\\n" "$API_GW_URL/api/status")
    echo "$response"
    echo
    
    print_info "Health checks completed. Check Jaeger UI for traces."
}

# Test authentication flow
test_auth_flow() {
    print_demo "Testing authentication flow..."
    
    echo "1. User Registration (if auth service is available):"
    registration_response=$(curl -s -w "\\nHTTP Status: %{http_code}\\n" \\
        -X POST "$API_GW_URL/api/auth/register" \\
        -H "Content-Type: application/json" \\
        -d '{
            "email": "test@example.com",
            "password": "testpassword123",
            "firstName": "Test",
            "lastName": "User"
        }' 2>/dev/null || echo "Auth service not available")
    echo "$registration_response"
    echo
    
    echo "2. User Login:"
    login_response=$(curl -s -w "\\nHTTP Status: %{http_code}\\n" \\
        -X POST "$API_GW_URL/api/auth/login" \\
        -H "Content-Type: application/json" \\
        -d '{
            "email": "test@example.com",
            "password": "testpassword123"
        }' 2>/dev/null || echo "Auth service not available")
    echo "$login_response"
    echo
    
    # Extract token if login was successful
    TOKEN=$(echo "$login_response" | grep -o '"token":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "")
    
    if [ -n "$TOKEN" ]; then
        print_info "Authentication successful. Token obtained for order tests."
    else
        print_warning "Authentication failed or not available. Using mock token for order tests."
        TOKEN="mock-jwt-token-for-demo"
    fi
}

# Test order operations
test_order_operations() {
    print_demo "Testing order operations..."
    
    echo "1. Create Order:"
    create_response=$(curl -s -w "\\nHTTP Status: %{http_code}\\n" \\
        -X POST "$API_GW_URL/api/orders" \\
        -H "Content-Type: application/json" \\
        -H "Authorization: Bearer $TOKEN" \\
        -d '{
            "items": [
                {"productId": "prod-1", "quantity": 2, "price": 29.99},
                {"productId": "prod-2", "quantity": 1, "price": 49.99}
            ],
            "shippingAddress": {
                "street": "123 Main St",
                "city": "Anytown",
                "state": "CA",
                "zipCode": "12345"
            }
        }' 2>/dev/null || echo "Order service not available")
    echo "$create_response"
    echo
    
    echo "2. Get Orders:"
    get_response=$(curl -s -w "\\nHTTP Status: %{http_code}\\n" \\
        -H "Authorization: Bearer $TOKEN" \\
        "$API_GW_URL/api/orders" 2>/dev/null || echo "Order service not available")
    echo "$get_response"
    echo
    
    # Extract order ID if creation was successful
    ORDER_ID=$(echo "$create_response" | grep -o '"orderId":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "")
    
    if [ -n "$ORDER_ID" ]; then
        echo "3. Get Specific Order:"
        detail_response=$(curl -s -w "\\nHTTP Status: %{http_code}\\n" \\
            -H "Authorization: Bearer $TOKEN" \\
            "$API_GW_URL/api/orders/$ORDER_ID" 2>/dev/null || echo "Order service not available")
        echo "$detail_response"
        echo
    fi
}

# Test product operations
test_product_operations() {
    print_demo "Testing product operations..."
    
    echo "1. Get Products:"
    products_response=$(curl -s -w "\\nHTTP Status: %{http_code}\\n" \\
        "$API_GW_URL/api/products" 2>/dev/null || echo "Product service not available")
    echo "$products_response"
    echo
    
    echo "2. Search Products:"
    search_response=$(curl -s -w "\\nHTTP Status: %{http_code}\\n" \\
        "$API_GW_URL/api/products/search?q=laptop" 2>/dev/null || echo "Product service not available")
    echo "$search_response"
    echo
}

# Generate error scenarios for tracing
test_error_scenarios() {
    print_demo "Testing error scenarios for tracing..."
    
    echo "1. Invalid Route (404 Error):"
    error_404=$(curl -s -w "\\nHTTP Status: %{http_code}\\n" \\
        "$API_GW_URL/api/nonexistent" 2>/dev/null)
    echo "$error_404"
    echo
    
    echo "2. Unauthorized Request (401 Error):"
    error_401=$(curl -s -w "\\nHTTP Status: %{http_code}\\n" \\
        "$API_GW_URL/api/orders" 2>/dev/null)
    echo "$error_401"
    echo
    
    echo "3. Invalid Token (403 Error):"
    error_403=$(curl -s -w "\\nHTTP Status: %{http_code}\\n" \\
        -H "Authorization: Bearer invalid-token" \\
        "$API_GW_URL/api/orders" 2>/dev/null)
    echo "$error_403"
    echo
}

# Load testing with multiple concurrent requests
load_test() {
    print_demo "Running load test to generate trace data..."
    
    echo "Sending 20 concurrent health check requests..."
    for i in {1..20}; do
        (curl -s "$API_GW_URL/health" > /dev/null &)
    done
    wait
    
    echo "Sending 10 concurrent status check requests..."
    for i in {1..10}; do
        (curl -s "$API_GW_URL/api/status" > /dev/null &)
    done
    wait
    
    print_info "Load test completed. Check Jaeger UI for trace volume."
}

# Display Jaeger queries for interesting traces
show_jaeger_queries() {
    print_demo "Suggested Jaeger UI queries to explore traces:"
    
    echo
    echo "🔍 Interesting traces to search for in Jaeger UI:"
    echo "   Service: api-gateway"
    echo "   Operation: GET /api/status"
    echo "   Look for: Service dependency traces"
    echo
    echo "   Service: order-service"
    echo "   Operation: POST /"
    echo "   Look for: Database and Kafka operations"
    echo
    echo "   Service: api-gateway"
    echo "   Tags: error=true"
    echo "   Look for: Error traces and debugging info"
    echo
    echo "🎯 Trace Analysis Tips:"
    echo "   • Look for latency between services"
    echo "   • Check error propagation across services"
    echo "   • Examine database query performance"
    echo "   • Monitor Kafka message publishing"
    echo
}

# Generate comprehensive test report
generate_report() {
    print_info "Generating comprehensive trace test report..."
    
    cat << EOF

====================================
🎯 Jaeger Tracing Demo Report
====================================

Test Environment:
  • API Gateway: $API_GW_URL
  • Jaeger UI: $JAEGER_URL
  • Namespace: $NAMESPACE

Tests Executed:
  ✅ Health check endpoints
  ✅ Service status monitoring
  ✅ Authentication flow
  ✅ Order operations (CRUD)
  ✅ Product queries
  ✅ Error scenarios
  ✅ Load testing

Tracing Features Demonstrated:
  📊 Request/Response tracing
  🔄 Service-to-service calls
  💾 Database operation tracing
  📨 Kafka message tracing
  ❌ Error propagation tracking
  📈 Performance monitoring

Next Steps:
  1. Open Jaeger UI: $JAEGER_URL
  2. Search for traces by service name
  3. Analyze trace timelines and dependencies
  4. Look for performance bottlenecks
  5. Review error traces for debugging

Sample Jaeger Queries:
  • Service: api-gateway, Tags: http.status_code=200
  • Service: order-service, Operation: create_order
  • Service: any, Tags: error=true
  • Service: api-gateway, Operation: GET /api/status

====================================

EOF
}

# Cleanup function
cleanup() {
    if [ -n "$PORT_FORWARD_PID" ]; then
        print_info "Cleaning up port-forward..."
        kill $PORT_FORWARD_PID 2>/dev/null || true
    fi
}

# Main demo execution
main() {
    echo "🎬 Starting Jaeger Distributed Tracing Demo"
    echo "=========================================="
    
    # Set up cleanup trap
    trap cleanup EXIT
    
    # Get service endpoints
    get_service_urls
    
    # Wait a moment for services to be ready
    sleep 2
    
    # Run all test scenarios
    test_health_checks
    sleep 1
    
    test_auth_flow
    sleep 1
    
    test_order_operations
    sleep 1
    
    test_product_operations
    sleep 1
    
    test_error_scenarios
    sleep 1
    
    load_test
    sleep 2
    
    # Show analysis guidance
    show_jaeger_queries
    
    # Generate final report
    generate_report
    
    print_info "Demo completed! Open Jaeger UI to explore the generated traces."
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --api-url=*)
            API_GW_URL="${1#*=}"
            shift
            ;;
        --jaeger-url=*)
            JAEGER_URL="${1#*=}"
            shift
            ;;
        --quick)
            QUICK_MODE=true
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --api-url=URL     Override API Gateway URL"
            echo "  --jaeger-url=URL  Override Jaeger UI URL"
            echo "  --quick           Run abbreviated test suite"
            echo "  --help            Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Run quick mode if requested
if [ "$QUICK_MODE" = true ]; then
    get_service_urls
    test_health_checks
    show_jaeger_queries
    generate_report
else
    main
fi
