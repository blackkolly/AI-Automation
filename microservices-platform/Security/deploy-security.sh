#!/bin/bash

# Kubernetes Security Deployment Script
# This script applies comprehensive security configurations

set -e

echo "🔒 Deploying Kubernetes Security Configurations..."

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

print_status "Kubernetes cluster is accessible ✓"

# Label namespaces for network policies
print_status "Labeling namespaces for network policies..."
kubectl label namespace microservices name=microservices --overwrite
kubectl label namespace monitoring name=monitoring --overwrite
kubectl label namespace observability name=observability --overwrite
kubectl label namespace istio-system name=istio-system --overwrite
kubectl label namespace default name=default --overwrite

print_success "Namespaces labeled for network policies"

# Apply RBAC configurations
print_status "Applying RBAC configurations..."
kubectl apply -f Security/rbac.yaml

print_success "RBAC configurations applied"

# Apply network policies
print_status "Applying network policies..."
kubectl apply -f Security/network-policies.yaml

print_success "Network policies applied"

# Apply security secrets and configs
print_status "Applying security secrets and configurations..."
kubectl apply -f Security/secrets.yaml

print_success "Security secrets and configurations applied"

# Apply pod security configurations
print_status "Applying pod security standards..."
kubectl apply -f Security/pod-security.yaml

print_success "Pod security standards applied"

# Verify security configurations
print_status "Verifying security configurations..."

echo "🔍 Checking NetworkPolicies..."
kubectl get networkpolicies -A

echo "🔍 Checking RBAC configurations..."
kubectl get serviceaccounts -n microservices
kubectl get roles -n microservices
kubectl get rolebindings -n microservices

echo "🔍 Checking secrets..."
kubectl get secrets -n microservices

echo "🔍 Checking resource quotas and limits..."
kubectl get resourcequota -n microservices
kubectl get limitrange -n microservices

print_success "🎉 Kubernetes security configurations deployed successfully!"

echo ""
echo "📋 Security Summary"
echo "=================="
echo "✅ Network Policies: Implemented"
echo "✅ RBAC: Service accounts, roles, and bindings configured"
echo "✅ Secrets Management: Secure credential storage"
echo "✅ Pod Security: Security contexts and standards"
echo "✅ Resource Limits: Quotas and limits applied"
echo "✅ Istio Security: mTLS and authorization policies"

echo ""
echo "🔧 Security Best Practices Applied:"
echo "1. Network segmentation with NetworkPolicies"
echo "2. Least privilege access with RBAC"
echo "3. Secure secret management"
echo "4. Non-root containers with security contexts"
echo "5. Resource quotas to prevent resource exhaustion"
echo "6. Pod disruption budgets for availability"
echo "7. mTLS encryption with Istio service mesh"

echo ""
echo "⚠️  Next Steps for Production:"
echo "1. Replace example secrets with real credentials"
echo "2. Configure image vulnerability scanning"
echo "3. Set up admission controllers (OPA Gatekeeper)"
echo "4. Enable audit logging"
echo "5. Implement external secret management (Vault, etc.)"
echo "6. Configure security monitoring and alerting"
