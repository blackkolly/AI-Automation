#!/bin/bash

# Istio Installation using Helm (Alternative to downloading Istio)
# This approach uses Helm charts instead of istioctl

set -e

echo "🚀 Installing Istio using Helm (No Download Required)..."

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

# Check prerequisites
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed"
    exit 1
fi

if ! command -v helm &> /dev/null; then
    print_error "helm is not installed"
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

print_status "Prerequisites check passed"

# Step 1: Add Istio Helm repository
print_status "Step 1: Adding Istio Helm repository..."
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update

print_success "Istio Helm repository added"

# Step 2: Create istio-system namespace
print_status "Step 2: Creating istio-system namespace..."
kubectl create namespace istio-system --dry-run=client -o yaml | kubectl apply -f -

# Step 3: Install Istio base components
print_status "Step 3: Installing Istio base components..."
helm upgrade --install istio-base istio/base -n istio-system --wait

print_success "Istio base components installed"

# Step 4: Install Istio control plane (istiod)
print_status "Step 4: Installing Istio control plane..."
helm upgrade --install istiod istio/istiod -n istio-system --wait

print_success "Istio control plane installed"

# Step 5: Install Istio Ingress Gateway
print_status "Step 5: Installing Istio Ingress Gateway..."
helm upgrade --install istio-ingressgateway istio/gateway -n istio-system --wait

print_success "Istio Ingress Gateway installed"

# Step 6: Enable sidecar injection
print_status "Step 6: Enabling sidecar injection for microservices namespace..."

# Create microservices namespace if it doesn't exist
kubectl create namespace microservices --dry-run=client -o yaml | kubectl apply -f -

# Enable istio injection
kubectl label namespace microservices istio-injection=enabled --overwrite

print_success "Sidecar injection enabled"

# Step 7: Install observability addons
print_status "Step 7: Installing observability tools..."

# Install Kiali
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.26/samples/addons/kiali.yaml

# Install Jaeger  
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.26/samples/addons/jaeger.yaml

# Install Grafana
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.26/samples/addons/grafana.yaml

# Install Prometheus
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.26/samples/addons/prometheus.yaml

print_success "Observability tools installed"

# Step 8: Wait for all components to be ready
print_status "Step 8: Waiting for components to be ready..."

kubectl wait --for=condition=available --timeout=300s deployment/istiod -n istio-system
kubectl wait --for=condition=available --timeout=300s deployment/istio-ingressgateway -n istio-system

print_success "Istio is ready!"

# Step 9: Apply custom configurations
print_status "Step 9: Applying custom Istio configurations..."

if [ -f "01-gateway.yaml" ]; then
    kubectl apply -f 01-gateway.yaml
    print_success "Gateway configuration applied"
fi

if [ -f "02-virtual-services.yaml" ]; then
    kubectl apply -f 02-virtual-services.yaml
    print_success "VirtualServices configuration applied"
fi

if [ -f "03-destination-rules.yaml" ]; then
    kubectl apply -f 03-destination-rules.yaml
    print_success "DestinationRules configuration applied"
fi

if [ -f "04-security-policies.yaml" ]; then
    kubectl apply -f 04-security-policies.yaml
    print_success "Security policies applied"
fi

if [ -f "05-observability.yaml" ]; then
    kubectl apply -f 05-observability.yaml
    print_success "Observability configuration applied"
fi

if [ -f "06-advanced-traffic.yaml" ]; then
    kubectl apply -f 06-advanced-traffic.yaml
    print_success "Advanced traffic policies applied"
fi

# Step 10: Verification
print_status "Step 10: Verifying installation..."

echo "Istio components status:"
kubectl get pods -n istio-system

echo -e "\nIstio gateways:"
kubectl get gateway -A

echo -e "\nHelm releases:"
helm list -n istio-system

print_success "🎉 Istio installation completed using Helm!"

# Access information
echo -e "\n${BLUE}=== Access Information ===${NC}"
echo "Set up port forwarding to access Istio components:"
echo ""
echo "# Kiali Dashboard"
echo "kubectl port-forward svc/kiali 20001:20001 -n istio-system"
echo "Access: http://localhost:20001"
echo ""
echo "# Jaeger UI"
echo "kubectl port-forward svc/jaeger 16686:16686 -n istio-system"
echo "Access: http://localhost:16686"
echo ""
echo "# Grafana"
echo "kubectl port-forward svc/grafana 3000:3000 -n istio-system"
echo "Access: http://localhost:3000"
echo ""
echo "# Prometheus"
echo "kubectl port-forward svc/prometheus 9090:9090 -n istio-system"
echo "Access: http://localhost:9090"
echo ""
echo "# Main Application (through Istio Gateway)"
echo "kubectl port-forward svc/istio-ingressgateway 8080:80 -n istio-system"
echo "Access: http://localhost:8080"

print_status "Next steps:"
echo "1. Restart your microservices deployments to inject sidecars"
echo "2. Test your applications through the Istio gateway"
echo "3. Monitor service mesh in Kiali dashboard"
