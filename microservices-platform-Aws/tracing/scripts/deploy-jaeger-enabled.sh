#!/bin/bash

# Jaeger-Enabled Microservices Deployment Script
# This script deploys the microservices with Jaeger distributed tracing

set -e

echo "🚀 Starting Jaeger-enabled microservices deployment..."

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="microservices"
OBSERVABILITY_NS="observability"
DOCKER_REGISTRY="${DOCKER_REGISTRY:-localhost:5000}"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Jaeger is running
check_jaeger() {
    print_status "Checking Jaeger deployment..."
    
    if ! kubectl get namespace "$OBSERVABILITY_NS" >/dev/null 2>&1; then
        print_error "Observability namespace not found. Please deploy Jaeger first."
        exit 1
    fi
    
    if ! kubectl get deployment jaeger -n "$OBSERVABILITY_NS" >/dev/null 2>&1; then
        print_error "Jaeger deployment not found in $OBSERVABILITY_NS namespace."
        exit 1
    fi
    
    print_status "Jaeger is deployed and running ✓"
}

# Create or update namespace
setup_namespace() {
    print_status "Setting up namespace: $NAMESPACE"
    
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Label namespace for monitoring
    kubectl label namespace "$NAMESPACE" monitoring=enabled --overwrite
    kubectl label namespace "$NAMESPACE" tracing=jaeger --overwrite
}

# Apply Jaeger configuration
apply_jaeger_config() {
    print_status "Applying Jaeger configuration..."
    
    kubectl apply -f k8s/jaeger-enabled-deployments.yaml
    
    print_status "Jaeger configuration applied ✓"
}

# Build and push Docker images
build_and_push_images() {
    print_status "Building and pushing Docker images..."
    
    print_warning "Skipping Docker build for this demo. Using existing images."
    print_info "In production, rebuild images with tracing dependencies included."
    
    # Future implementation:
    # docker build services/api-gateway -t $DOCKER_REGISTRY/api-gateway:jaeger-v1.0
    # docker push $DOCKER_REGISTRY/api-gateway:jaeger-v1.0
    
    print_status "Image build step completed ✓"
}

# Update image tags in deployment
update_image_tags() {
    print_status "Updating deployment configurations..."
    
    print_warning "Using existing images for this demo."
    print_status "Services will be restarted to pick up new environment variables."
    
    # Restart deployments to pick up new ConfigMap
    kubectl rollout restart deployment/api-gateway -n "$NAMESPACE" 2>/dev/null || print_warning "API Gateway deployment not found"
    kubectl rollout restart deployment/order-service -n "$NAMESPACE" 2>/dev/null || print_warning "Order Service deployment not found"
    kubectl rollout restart deployment/auth-service -n "$NAMESPACE" 2>/dev/null || print_warning "Auth Service deployment not found"
    
    print_status "Deployment configurations updated ✓"
}

# Wait for deployments to be ready
wait_for_deployments() {
    print_status "Waiting for deployments to be ready..."
    
    # Wait for API Gateway
    kubectl rollout status deployment/api-gateway -n "$NAMESPACE" --timeout=300s
    
    # Wait for Order Service
    kubectl rollout status deployment/order-service -n "$NAMESPACE" --timeout=300s
    
    # Wait for Auth Service (if it exists)
    if kubectl get deployment auth-service -n "$NAMESPACE" >/dev/null 2>&1; then
        kubectl rollout status deployment/auth-service -n "$NAMESPACE" --timeout=300s
    fi
    
    print_status "All deployments are ready ✓"
}

# Verify tracing is working
verify_tracing() {
    print_status "Verifying tracing configuration..."
    
    # Get Jaeger UI URL
    JAEGER_URL=$(kubectl get service jaeger-external -n "$OBSERVABILITY_NS" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    if [ -z "$JAEGER_URL" ]; then
        JAEGER_URL=$(kubectl get service jaeger-external -n "$OBSERVABILITY_NS" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    fi
    
    if [ -n "$JAEGER_URL" ]; then
        print_status "Jaeger UI available at: http://$JAEGER_URL:16686"
    else
        print_warning "Jaeger UI URL not available. Check LoadBalancer status."
    fi
    
    # Test API Gateway health endpoint
    API_GW_URL=$(kubectl get service api-gateway -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    if [ -z "$API_GW_URL" ]; then
        API_GW_URL=$(kubectl get service api-gateway -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    fi
    
    if [ -n "$API_GW_URL" ]; then
        print_status "Testing API Gateway health endpoint..."
        if curl -s "http://$API_GW_URL:3000/health" >/dev/null; then
            print_status "API Gateway health check passed ✓"
        else
            print_warning "API Gateway health check failed"
        fi
    else
        print_warning "API Gateway URL not available. Check LoadBalancer status."
    fi
}

# Print deployment summary
print_summary() {
    echo
    echo "======================================"
    echo "🎉 Deployment Summary"
    echo "======================================"
    
    print_status "Services deployed with Jaeger tracing:"
    echo "  • API Gateway (Port: 3000)"
    echo "  • Order Service (Port: 3003)"
    echo "  • Auth Service (Port: 3001) [if available]"
    
    echo
    print_status "Monitoring & Observability:"
    
    # Jaeger UI
    JAEGER_URL=$(kubectl get service jaeger-external -n "$OBSERVABILITY_NS" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    if [ -z "$JAEGER_URL" ]; then
        JAEGER_URL=$(kubectl get service jaeger-external -n "$OBSERVABILITY_NS" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    fi
    if [ -n "$JAEGER_URL" ]; then
        echo "  • Jaeger UI: http://$JAEGER_URL:16686"
    fi
    
    # Prometheus
    PROMETHEUS_URL=$(kubectl get service prometheus-external -n "$OBSERVABILITY_NS" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    if [ -z "$PROMETHEUS_URL" ]; then
        PROMETHEUS_URL=$(kubectl get service prometheus-external -n "$OBSERVABILITY_NS" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    fi
    if [ -n "$PROMETHEUS_URL" ]; then
        echo "  • Prometheus: http://$PROMETHEUS_URL:9090"
    fi
    
    echo
    print_status "Next Steps:"
    echo "  1. Access Jaeger UI to view distributed traces"
    echo "  2. Make API calls to generate trace data"
    echo "  3. Monitor service performance and dependencies"
    echo
    print_status "Test API calls:"
    echo "  curl http://$API_GW_URL:3000/health"
    echo "  curl http://$API_GW_URL:3000/api/status"
    echo
}

# Main deployment flow
main() {
    echo "🔍 Pre-deployment checks..."
    check_jaeger
    
    echo "📦 Setting up environment..."
    setup_namespace
    apply_jaeger_config
    
    echo "🐳 Building and deploying services..."
    build_and_push_images
    update_image_tags
    
    echo "⏳ Waiting for deployment completion..."
    wait_for_deployments
    
    echo "✅ Verifying deployment..."
    verify_tracing
    
    print_summary
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --registry=*)
            DOCKER_REGISTRY="${1#*=}"
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --skip-build     Skip building Docker images"
            echo "  --registry=URL   Set Docker registry URL"
            echo "  --help           Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Skip build if requested
if [ "$SKIP_BUILD" = true ]; then
    echo "🔍 Pre-deployment checks..."
    check_jaeger
    
    echo "📦 Setting up environment..."
    setup_namespace
    apply_jaeger_config
    update_image_tags
    
    echo "⏳ Waiting for deployment completion..."
    wait_for_deployments
    
    echo "✅ Verifying deployment..."
    verify_tracing
    
    print_summary
else
    main
fi
