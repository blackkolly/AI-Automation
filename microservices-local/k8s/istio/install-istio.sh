#!/bin/bash

# Istio Service Mesh Installation and Configuration Script
# This script installs Istio and applies all configurations for the microservices platform

set -e

echo "🚀 Starting Istio Service Mesh Installation..."

# Colors for output
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
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

print_status "Kubernetes cluster is accessible"

# Step 1: Download and install Istio
print_status "Step 1: Installing Istio..."

if ! command -v istioctl &> /dev/null; then
    print_status "Downloading Istio..."
    curl -L https://istio.io/downloadIstio | sh -
    
    # Find the latest Istio directory
    ISTIO_DIR=$(find . -name "istio-*" -type d | head -1)
    if [ -z "$ISTIO_DIR" ]; then
        print_error "Failed to find Istio directory"
        exit 1
    fi
    
    # Add istioctl to PATH for this session
    export PATH="$PWD/$ISTIO_DIR/bin:$PATH"
    print_success "Istio downloaded and istioctl added to PATH"
else
    print_success "istioctl is already installed"
fi

# Step 2: Install Istio control plane
print_status "Step 2: Installing Istio control plane..."

istioctl install --set values.defaultRevision=default -y

if [ $? -eq 0 ]; then
    print_success "Istio control plane installed successfully"
else
    print_error "Failed to install Istio control plane"
    exit 1
fi

# Step 3: Enable automatic sidecar injection
print_status "Step 3: Enabling automatic sidecar injection for microservices namespace..."

kubectl label namespace microservices istio-injection=enabled --overwrite

if [ $? -eq 0 ]; then
    print_success "Automatic sidecar injection enabled for microservices namespace"
else
    print_warning "Failed to enable sidecar injection - namespace might not exist yet"
fi

# Step 4: Install Istio addons (observability tools)
print_status "Step 4: Installing Istio addons (Kiali, Jaeger, Grafana, Prometheus)..."

kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/kiali.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/jaeger.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/grafana.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/prometheus.yaml

print_success "Istio addons installed"

# Step 5: Wait for Istio components to be ready
print_status "Step 5: Waiting for Istio components to be ready..."

kubectl wait --for=condition=available --timeout=300s deployment/istiod -n istio-system
kubectl wait --for=condition=available --timeout=300s deployment/kiali -n istio-system
kubectl wait --for=condition=available --timeout=300s deployment/jaeger -n istio-system
kubectl wait --for=condition=available --timeout=300s deployment/grafana -n istio-system
kubectl wait --for=condition=available --timeout=300s deployment/prometheus -n istio-system

print_success "All Istio components are ready"

# Step 6: Apply custom Istio configurations
print_status "Step 6: Applying custom Istio configurations..."

# Create observability gateway first
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: observability-gateway
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - kiali.local
    - jaeger.local
    - grafana.local
    - prometheus.local
EOF

# Apply all Istio configurations
print_status "Applying Gateway configuration..."
kubectl apply -f 01-gateway.yaml

print_status "Applying VirtualServices configuration..."
kubectl apply -f 02-virtual-services.yaml

print_status "Applying DestinationRules configuration..."
kubectl apply -f 03-destination-rules.yaml

print_status "Applying Security Policies..."
kubectl apply -f 04-security-policies.yaml

print_status "Applying Observability configuration..."
kubectl apply -f 05-observability.yaml

print_status "Applying Advanced Traffic policies..."
kubectl apply -f 06-advanced-traffic.yaml

print_success "All Istio configurations applied successfully"

# Step 7: Verify installation
print_status "Step 7: Verifying Istio installation..."

echo "Checking Istio control plane status:"
kubectl get pods -n istio-system

echo -e "\nChecking Istio gateways:"
kubectl get gateway -A

echo -e "\nChecking Virtual Services:"
kubectl get virtualservice -A

echo -e "\nChecking Destination Rules:"
kubectl get destinationrule -A

print_success "Istio installation and configuration completed!"

# Step 8: Provide access information
echo -e "\n${BLUE}=== Access Information ===${NC}"
echo "To access the Istio components, set up port forwarding:"
echo ""
echo "# Kiali Dashboard (Service Mesh Observability)"
echo "kubectl port-forward svc/kiali 20001:20001 -n istio-system"
echo "Access: http://localhost:20001"
echo ""
echo "# Jaeger (Distributed Tracing)"
echo "kubectl port-forward svc/jaeger 16686:16686 -n istio-system"
echo "Access: http://localhost:16686"
echo ""
echo "# Grafana (Metrics Dashboard)"
echo "kubectl port-forward svc/grafana 3000:3000 -n istio-system"
echo "Access: http://localhost:3000"
echo ""
echo "# Prometheus (Metrics Collection)"
echo "kubectl port-forward svc/prometheus 9090:9090 -n istio-system"
echo "Access: http://localhost:9090"
echo ""
echo "# Main Application (API Gateway)"
echo "kubectl port-forward svc/istio-ingressgateway 8080:80 -n istio-system"
echo "Access: http://localhost:8080"
echo ""

# Add entries to /etc/hosts for local development
echo -e "${YELLOW}=== Local Development Setup ===${NC}"
echo "Add these entries to your /etc/hosts file (or C:\\Windows\\System32\\drivers\\etc\\hosts on Windows):"
echo "127.0.0.1 api.microservices.local"
echo "127.0.0.1 kiali.local"
echo "127.0.0.1 jaeger.local"
echo "127.0.0.1 grafana.local"
echo "127.0.0.1 prometheus.local"
echo ""

print_success "🎉 Istio Service Mesh is ready for your microservices platform!"
print_status "Next steps:"
echo "1. Restart your microservices deployments to inject Istio sidecars"
echo "2. Test traffic routing and security policies"
echo "3. Monitor service mesh metrics in Kiali dashboard"
echo "4. Use Jaeger for distributed tracing analysis"
