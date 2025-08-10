#!/bin/bash

# Deploy Istio Service Mesh for Local Kubernetes
# This script installs and configures Istio with all necessary components

set -e

echo "🚀 Starting Istio Service Mesh Deployment for Local Kubernetes..."

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

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster. Make sure Docker Desktop Kubernetes is running."
    exit 1
fi

print_status "Kubernetes cluster is accessible ✓"

# Check if Istio is already installed
if kubectl get namespace istio-system &> /dev/null; then
    print_warning "Istio system namespace already exists. This script will update the configuration."
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Deployment cancelled."
        exit 0
    fi
fi

# Download and install Istio CLI (istioctl) if not present
ISTIO_VERSION="1.19.3"
if ! command -v istioctl &> /dev/null; then
    print_status "Installing Istio CLI (istioctl)..."
    
    # Detect OS
    OS="$(uname -s)"
    case "${OS}" in
        Linux*)     PLATFORM=linux-amd64;;
        Darwin*)    PLATFORM=osx;;
        CYGWIN*|MINGW*|MSYS*)    PLATFORM=win;;
        *)          print_error "Unsupported operating system: ${OS}"; exit 1;;
    esac
    
    # Download Istio
    curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$ISTIO_VERSION sh -
    
    # Add to PATH for current session
    export PATH="$PWD/istio-$ISTIO_VERSION/bin:$PATH"
    
    print_success "Istio CLI installed successfully"
else
    print_status "Istio CLI already installed ✓"
fi

# Install Istio with demo profile for local development
print_status "Installing Istio with demo profile..."
istioctl install --set values.defaultRevision=default --set values.pilot.traceSampling=100.0 -y

print_success "Istio control plane installed"

# Enable Istio injection for microservices namespace
print_status "Enabling Istio sidecar injection for microservices namespace..."
kubectl label namespace microservices istio-injection=enabled --overwrite
kubectl label namespace monitoring istio-injection=enabled --overwrite
kubectl label namespace observability istio-injection=enabled --overwrite

print_success "Istio sidecar injection enabled for namespaces"

# Apply Istio configurations
print_status "Applying Istio Gateway configurations..."
kubectl apply -f k8s/istio/gateway.yaml

print_status "Applying Istio Virtual Services..."
kubectl apply -f k8s/istio/virtual-services.yaml

print_status "Applying Istio Destination Rules..."
kubectl apply -f k8s/istio/destination-rules.yaml

print_status "Applying Istio Security Policies..."
kubectl apply -f k8s/istio/security-policies.yaml

print_status "Applying Istio Observability Configuration..."
kubectl apply -f k8s/istio/observability-config.yaml

# Install Kiali dashboard
print_status "Installing Kiali dashboard..."
kubectl apply -f k8s/istio/addons/kiali.yaml

# Wait for Istio components to be ready
print_status "Waiting for Istio components to be ready..."
kubectl wait --for=condition=ready pod -l app=istiod -n istio-system --timeout=300s
kubectl wait --for=condition=ready pod -l app=istio-proxy -n istio-system --timeout=300s || print_warning "Istio proxy pods may not be ready yet"

# Restart deployments to inject Istio sidecars
print_status "Restarting microservices to inject Istio sidecars..."
kubectl rollout restart deployment/api-gateway -n microservices
kubectl rollout restart deployment/auth-service -n microservices
kubectl rollout restart deployment/product-service -n microservices
kubectl rollout restart deployment/order-service -n microservices

# Wait for deployments to be ready
print_status "Waiting for microservices to be ready with Istio sidecars..."
kubectl rollout status deployment/api-gateway -n microservices --timeout=300s
kubectl rollout status deployment/auth-service -n microservices --timeout=300s
kubectl rollout status deployment/product-service -n microservices --timeout=300s
kubectl rollout status deployment/order-service -n microservices --timeout=300s

# Wait for Kiali to be ready
print_status "Waiting for Kiali dashboard to be ready..."
kubectl wait --for=condition=ready pod -l app=kiali -n istio-system --timeout=300s

# Get access information
print_success "🎉 Istio Service Mesh deployment completed successfully!"
echo ""
echo "📊 Access Information:"
echo "===================="

# Istio Gateway External IP
GATEWAY_IP=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "localhost")
if [ "$GATEWAY_IP" = "localhost" ] || [ -z "$GATEWAY_IP" ]; then
    GATEWAY_PORT=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
    echo "🌐 Microservices Gateway: http://localhost:$GATEWAY_PORT"
else
    echo "🌐 Microservices Gateway: http://$GATEWAY_IP"
fi

# Kiali Dashboard
KIALI_PORT=$(kubectl get svc kiali -n istio-system -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
if [ -z "$KIALI_PORT" ]; then
    echo "📈 Kiali Dashboard: kubectl port-forward svc/kiali -n istio-system 20001:20001 (then visit http://localhost:20001)"
else
    echo "📈 Kiali Dashboard: http://localhost:$KIALI_PORT"
fi

# Existing monitoring tools
echo "📊 Prometheus: http://localhost:30090"
echo "📈 Grafana: http://localhost:30300 (admin/admin)"
echo "🔍 Jaeger: http://localhost:30686"

echo ""
echo "🔧 Host File Entries (optional for better access):"
echo "=================================================="
echo "Add these to your /etc/hosts (Linux/Mac) or C:\\Windows\\System32\\drivers\\etc\\hosts (Windows):"
echo "127.0.0.1 grafana.local"
echo "127.0.0.1 prometheus.local" 
echo "127.0.0.1 kiali.local"
echo "127.0.0.1 jaeger.local"

echo ""
echo "🚀 Istio Features Enabled:"
echo "========================="
echo "✅ Traffic Management (Load Balancing, Circuit Breakers)"
echo "✅ Security (mTLS, Authorization Policies)"
echo "✅ Observability (Metrics, Tracing, Logging)"
echo "✅ Service Mesh Visualization (Kiali)"
echo "✅ Intelligent Routing and Canary Deployments"

echo ""
echo "🧪 Testing Istio:"
echo "================"
echo "1. Access the microservices through Istio Gateway"
echo "2. View service mesh topology in Kiali"
echo "3. Monitor traffic patterns and metrics"
echo "4. Test circuit breaker and retry policies"

echo ""
print_success "Istio Service Mesh is ready for production-grade microservices! 🎉"
