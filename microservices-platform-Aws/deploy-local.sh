#!/bin/bash

# Local Deployment Script for Microservices Platform
# This script deploys the entire platform on Docker Desktop Kubernetes

set -e

echo "🚀 Starting Local Microservices Platform Deployment"
echo "=================================================="

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
print_status "Checking prerequisites..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed. Please install kubectl first."
    exit 1
fi

# Check if helm is available
if ! command -v helm &> /dev/null; then
    print_error "helm is not installed. Please install helm first."
    exit 1
fi

# Check if Docker Desktop Kubernetes is running
if ! kubectl cluster-info &> /dev/null; then
    print_error "Kubernetes cluster is not accessible. Please ensure Docker Desktop Kubernetes is enabled and running."
    exit 1
fi

# Check if we're using docker-desktop context
CURRENT_CONTEXT=$(kubectl config current-context)
if [ "$CURRENT_CONTEXT" != "docker-desktop" ]; then
    print_warning "Current context is '$CURRENT_CONTEXT', switching to 'docker-desktop'"
    kubectl config use-context docker-desktop
fi

print_success "Prerequisites check completed"

# Create namespaces
print_status "Creating namespaces..."
kubectl create namespace microservices --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -
print_success "Namespaces created"

# Add Helm repositories
print_status "Adding Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo update
print_success "Helm repositories added"

# Install Prometheus Stack
print_status "Installing Prometheus monitoring stack..."
helm upgrade --install prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.service.type=NodePort \
  --set prometheus.service.nodePort=30090 \
  --set grafana.service.type=NodePort \
  --set grafana.service.nodePort=30300 \
  --set alertmanager.service.type=NodePort \
  --set alertmanager.service.nodePort=30903 \
  --set prometheus.prometheusSpec.retention=7d \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=5Gi \
  --set grafana.persistence.enabled=true \
  --set grafana.persistence.size=2Gi \
  --wait --timeout=10m

print_success "Prometheus stack installed"

# Install Jaeger
print_status "Installing Jaeger tracing..."
helm upgrade --install jaeger jaegertracing/jaeger \
  --namespace observability \
  --set query.service.type=NodePort \
  --set query.service.nodePort=30686 \
  --set collector.service.type=ClusterIP \
  --set agent.daemonset.enabled=true \
  --set storage.type=memory \
  --wait --timeout=5m

print_success "Jaeger installed"

# Deploy microservices
print_status "Deploying microservices..."
kubectl apply -f k8s/local/ -n microservices
print_success "Microservices deployed"

# Deploy ServiceMonitors
print_status "Deploying ServiceMonitors..."
kubectl apply -f k8s/local/local-servicemonitors.yaml
print_success "ServiceMonitors deployed"

# Wait for deployments to be ready
print_status "Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/api-gateway -n microservices
kubectl wait --for=condition=available --timeout=300s deployment/auth-service -n microservices
kubectl wait --for=condition=available --timeout=300s deployment/product-service -n microservices
kubectl wait --for=condition=available --timeout=300s deployment/order-service -n microservices

print_success "All deployments are ready"

# Display access information
echo ""
echo "🎉 Deployment Complete!"
echo "======================"
echo ""
echo "📊 Access your services at:"
echo "├── Grafana:      http://localhost:30300 (admin / prom-operator)"
echo "├── Prometheus:   http://localhost:30090"
echo "├── AlertManager: http://localhost:30903"
echo "├── Jaeger UI:    http://localhost:30686"
echo "└── API Gateway:  http://localhost:30000"
echo ""
echo "🔗 Microservice endpoints:"
echo "├── API Gateway:    http://localhost:30000/api/status"
echo "├── Auth Service:   http://localhost:30001/health"
echo "├── Product Service: http://localhost:30002/products"
echo "└── Order Service:   http://localhost:30003/orders"
echo ""
echo "📈 Quick health check:"
echo "curl http://localhost:30000/health"
echo ""
echo "🛠️  To check pod status:"
echo "kubectl get pods -n microservices"
echo "kubectl get pods -n monitoring"
echo "kubectl get pods -n observability"
echo ""
echo "🗑️  To clean up everything:"
echo "./cleanup-local.sh"
echo ""

print_success "Local microservices platform is now running!"
