#!/bin/bash

echo "🚀 Master Deployment Script for Microservices Platform"
echo "This script will deploy the complete observability stack..."
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to wait for deployment
wait_for_deployment() {
    local namespace=$1
    local deployment=$2
    echo "Waiting for $deployment in namespace $namespace to be ready..."
    kubectl wait --for=condition=available deployment/$deployment -n $namespace --timeout=300s
}

# Function to wait for pods
wait_for_pods() {
    local namespace=$1
    local label=$2
    echo "Waiting for pods with label $label in namespace $namespace to be ready..."
    kubectl wait --for=condition=ready pod -l $label -n $namespace --timeout=300s
}

# Check prerequisites
echo "🔍 Checking prerequisites..."
if ! command_exists kubectl; then
    echo "❌ kubectl is not installed. Please install kubectl first."
    exit 1
fi

if ! command_exists docker; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

echo "✅ Prerequisites check passed"
echo ""

# Get current directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "📂 Working directory: $SCRIPT_DIR"
echo ""

# Phase 1: Core Infrastructure
echo "📋 Phase 1: Deploying Core Infrastructure..."
echo "----------------------------------------"

# Install ArgoCD
echo "1. Installing ArgoCD..."
cd "$SCRIPT_DIR/argocd"
chmod +x install-argocd.sh
./install-argocd.sh
if [ $? -ne 0 ]; then
    echo "❌ ArgoCD installation failed"
    exit 1
fi
echo ""

# Phase 2: Service Mesh
echo "📋 Phase 2: Deploying Service Mesh..."
echo "------------------------------------"

# Install Istio
echo "2. Installing Istio Service Mesh..."
cd "$SCRIPT_DIR/istio"
chmod +x install-istio.sh
./install-istio.sh
if [ $? -ne 0 ]; then
    echo "❌ Istio installation failed"
    exit 1
fi
echo ""

# Phase 3: Security
echo "📋 Phase 3: Deploying Security Components..."
echo "--------------------------------------------"

# Install Security
echo "3. Installing Security Components..."
cd "$SCRIPT_DIR/security"
chmod +x install-security.sh
./install-security.sh
if [ $? -ne 0 ]; then
    echo "❌ Security installation failed"
    exit 1
fi
echo ""

# Phase 4: Observability - Logging
echo "📋 Phase 4: Deploying Logging Stack..."
echo "--------------------------------------"

# Install ELK Stack
echo "4. Installing ELK Stack..."
cd "$SCRIPT_DIR/logging"
chmod +x install-elk.sh
./install-elk.sh
if [ $? -ne 0 ]; then
    echo "❌ ELK Stack installation failed"
    exit 1
fi
echo ""

# Phase 5: Observability - Tracing
echo "📋 Phase 5: Deploying Tracing System..."
echo "---------------------------------------"

# Install Jaeger
echo "5. Installing Jaeger Tracing..."
cd "$SCRIPT_DIR/tracing"
chmod +x install-jaeger.sh
./install-jaeger.sh
if [ $? -ne 0 ]; then
    echo "❌ Jaeger installation failed"
    exit 1
fi
echo ""

# Phase 6: Verification
echo "📋 Phase 6: Verification and Health Checks..."
echo "---------------------------------------------"

echo "6. Verifying deployments..."

# Check ArgoCD
echo "Checking ArgoCD..."
kubectl get pods -n argocd | grep -E "(argocd-server|argocd-application-controller)" || echo "⚠️  ArgoCD pods not ready"

# Check Istio
echo "Checking Istio..."
kubectl get pods -n istio-system | grep istiod || echo "⚠️  Istio pods not ready"

# Check Security
echo "Checking Security..."
kubectl get networkpolicies -n microservices || echo "⚠️  Network policies not found"

# Check Logging
echo "Checking Logging..."
kubectl get pods -n logging | grep -E "(elasticsearch|kibana|filebeat)" || echo "⚠️  Logging pods not ready"

# Check Tracing
echo "Checking Tracing..."
kubectl get pods -n observability | grep -E "(jaeger|otel)" || echo "⚠️  Tracing pods not ready"

echo ""
echo "🎉 Deployment Summary"
echo "===================="
echo ""
echo "✅ ArgoCD GitOps: Continuous deployment and synchronization"
echo "✅ Istio Service Mesh: Traffic management, security, and observability"
echo "✅ Security: RBAC, network policies, and admission controllers"
echo "✅ ELK Stack: Centralized logging and log analysis"
echo "✅ Jaeger Tracing: Distributed tracing and performance monitoring"
echo ""
echo "🔗 Access URLs (after port-forwarding):"
echo "----------------------------------------"
echo "ArgoCD UI:     kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "               https://localhost:8080 (admin/admin)"
echo ""
echo "Kibana:        kubectl port-forward svc/kibana -n logging 5601:5601"
echo "               http://localhost:5601"
echo ""
echo "Jaeger UI:     kubectl port-forward svc/jaeger-query -n observability 16686:16686"
echo "               http://localhost:16686"
echo ""
echo "Grafana:       kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80"
echo "               http://localhost:3000 (admin/prom-operator)"
echo ""
echo "📊 Monitoring Commands:"
echo "----------------------"
echo "kubectl get pods --all-namespaces"
echo "kubectl get services --all-namespaces"
echo "kubectl get ingress --all-namespaces"
echo ""
echo "📝 Next Steps:"
echo "--------------"
echo "1. Deploy your microservices applications"
echo "2. Configure ArgoCD applications for GitOps"
echo "3. Set up monitoring dashboards in Grafana"
echo "4. Configure alerting rules"
echo "5. Implement tracing in your applications"
echo ""
echo "🚀 Platform deployment completed successfully!"
