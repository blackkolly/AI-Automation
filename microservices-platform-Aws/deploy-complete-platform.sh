#!/bin/bash

echo "🚀 Deploying Complete Microservices Platform with Observability Stack"
echo "=================================================================="

# Set error handling
set -e

# Color codes for output
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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Prerequisites check
print_status "Checking prerequisites..."

if ! command_exists kubectl; then
    print_error "kubectl is not installed. Please install kubectl first."
    exit 1
fi

if ! command_exists kind; then
    print_warning "kind not found. Using existing Kubernetes cluster."
fi

# Check if cluster is running
if ! kubectl cluster-info >/dev/null 2>&1; then
    print_error "Kubernetes cluster is not accessible. Please start your cluster first."
    exit 1
fi

print_success "Prerequisites check passed!"

# 1. Deploy Core Microservices
print_status "Step 1: Deploying core microservices..."
cd microservices-local
./deploy-local.sh
cd ..
print_success "Core microservices deployed!"

# 2. Install Istio Service Mesh
print_status "Step 2: Installing Istio Service Mesh..."
cd Istio
chmod +x install-istio.sh
./install-istio.sh
cd ..
print_success "Istio Service Mesh installed!"

# 3. Deploy Security Policies
print_status "Step 3: Deploying security policies..."
cd Security
kubectl apply -f rbac.yaml
kubectl apply -f network-policies-enhanced.yaml
kubectl apply -f pod-security.yaml
kubectl apply -f secrets.yaml
cd ..
print_success "Security policies deployed!"

# 4. Install Logging Stack (ELK)
print_status "Step 4: Installing ELK Stack for logging..."
cd logging
chmod +x install-elk.sh
./install-elk.sh
cd ..
print_success "ELK Stack installed!"

# 5. Install Tracing (Jaeger)
print_status "Step 5: Installing Jaeger for distributed tracing..."
cd tracing
chmod +x install-jaeger.sh
./install-jaeger.sh
cd ..
print_success "Jaeger tracing installed!"

# 6. Install ArgoCD for GitOps
print_status "Step 6: Installing ArgoCD for GitOps..."
cd argocd
chmod +x install-argocd.sh
./install-argocd.sh
cd ..
print_success "ArgoCD installed!"

# 7. Wait for all services to be ready
print_status "Step 7: Waiting for all services to be ready..."
sleep 30

# Check service status
print_status "Checking service status..."

# Microservices
kubectl get pods -n microservices
kubectl get svc -n microservices

# Istio
kubectl get pods -n istio-system
kubectl get svc -n istio-system

# Monitoring
kubectl get pods -n monitoring
kubectl get svc -n monitoring

# Logging
kubectl get pods -n logging
kubectl get svc -n logging

# Tracing
kubectl get pods -n tracing
kubectl get svc -n tracing

# ArgoCD
kubectl get pods -n argocd
kubectl get svc -n argocd

echo ""
echo "=================================================================="
print_success "🎉 DEPLOYMENT COMPLETE! 🎉"
echo "=================================================================="
echo ""
echo "📋 ACCESS URLS:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 Frontend Application:    http://localhost:30080"
echo "🔧 API Gateway:             http://localhost:30081"
echo "📊 Grafana (Monitoring):    http://localhost:30300"
echo "🔍 Prometheus:              http://localhost:30090"
echo "📈 Kibana (Logging):        http://localhost:30561"
echo "🔍 Jaeger (Tracing):        http://localhost:30686"
echo "🚀 ArgoCD (GitOps):         http://localhost:30080"
echo "🕸️  Kiali (Service Mesh):   http://localhost:30001"
echo ""
echo "🔑 DEFAULT CREDENTIALS:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Grafana:     admin / admin123"
echo "🚀 ArgoCD:       admin / (check with: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d)"
echo "📈 Kibana:       No authentication required"
echo "🔍 Jaeger:       No authentication required"
echo "🕸️  Kiali:       No authentication required"
echo ""
echo "📝 NEXT STEPS:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. Access the frontend application and test the microservices"
echo "2. Check Grafana for application metrics and monitoring"
echo "3. Use Kibana to search and analyze application logs"
echo "4. View distributed traces in Jaeger"
echo "5. Monitor service mesh traffic in Kiali"
echo "6. Manage deployments with ArgoCD"
echo ""
echo "💡 TIPS:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "• Generate traffic: curl http://localhost:30080/api/v1/products"
echo "• Check pod logs: kubectl logs -f <pod-name> -n microservices"
echo "• View Istio config: istioctl proxy-config cluster <pod-name> -n microservices"
echo "• Monitor resources: kubectl top pods -n microservices"
echo ""

# Optional: Open applications in browser (uncomment if desired)
# if command_exists xdg-open; then
#     xdg-open http://localhost:30080 &
#     xdg-open http://localhost:30300 &
# elif command_exists open; then
#     open http://localhost:30080 &
#     open http://localhost:30300 &
# fi

print_success "Platform is ready for use! 🚀"
