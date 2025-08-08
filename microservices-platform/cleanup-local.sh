#!/bin/bash

# Cleanup script for local deployment
# This script removes all local deployments and resources

set -e

echo "🧹 Cleaning up Local Microservices Platform"
echo "==========================================="

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

# Remove microservices
print_status "Removing microservices..."
kubectl delete -f k8s/local/ -n microservices --ignore-not-found=true
print_success "Microservices removed"

# Remove ServiceMonitors
print_status "Removing ServiceMonitors..."
kubectl delete -f k8s/local/local-servicemonitors.yaml --ignore-not-found=true
print_success "ServiceMonitors removed"

# Remove Helm releases
print_status "Removing Helm releases..."
helm uninstall prometheus-stack -n monitoring --ignore-not-found
helm uninstall jaeger -n observability --ignore-not-found
print_success "Helm releases removed"

# Clean up PVCs
print_status "Cleaning up persistent volumes..."
kubectl delete pvc -n monitoring --all --ignore-not-found=true
kubectl delete pvc -n observability --all --ignore-not-found=true
print_success "Persistent volumes cleaned"

# Remove namespaces (optional - uncomment if you want to remove everything)
# print_status "Removing namespaces..."
# kubectl delete namespace microservices --ignore-not-found=true
# kubectl delete namespace monitoring --ignore-not-found=true  
# kubectl delete namespace observability --ignore-not-found=true
# print_success "Namespaces removed"

print_warning "Namespaces preserved. To remove them manually:"
echo "kubectl delete namespace microservices monitoring observability"

echo ""
print_success "Local microservices platform cleanup completed!"
echo ""
echo "To redeploy, run: ./deploy-local.sh"
