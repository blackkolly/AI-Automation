#!/bin/bash

# ArgoCD Installation and Setup Script for Microservices Platform
set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🚀 Installing ArgoCD for Microservices Platform${NC}"
echo "=================================================="

# Install ArgoCD
echo -e "\n${BLUE}1. Installing ArgoCD...${NC}"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
echo -e "\n${BLUE}2. Waiting for ArgoCD to be ready...${NC}"
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd

# Patch ArgoCD server service to LoadBalancer
echo -e "\n${BLUE}3. Exposing ArgoCD UI via LoadBalancer...${NC}"
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Get initial admin password
echo -e "\n${BLUE}4. Getting ArgoCD admin password...${NC}"
ARGO_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# Wait for LoadBalancer IP
echo -e "\n${BLUE}5. Waiting for LoadBalancer IP...${NC}"
echo "This may take a few minutes..."

# Function to get LoadBalancer URL
get_lb_url() {
    kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo ""
}

# Wait for LoadBalancer
COUNTER=0
while [ $COUNTER -lt 30 ]; do
    LB_URL=$(get_lb_url)
    if [ ! -z "$LB_URL" ]; then
        break
    fi
    echo "Waiting for LoadBalancer... ($COUNTER/30)"
    sleep 10
    COUNTER=$((COUNTER + 1))
done

if [ ! -z "$LB_URL" ]; then
    echo -e "${GREEN}[✓]${NC} ArgoCD UI available at: http://$LB_URL"
else
    echo -e "${YELLOW}[WARNING]${NC} LoadBalancer IP not ready yet. Check later with:"
    echo "kubectl get svc argocd-server -n argocd"
fi

# Show login credentials
echo -e "\n${GREEN}🎉 ArgoCD Installation Complete!${NC}"
echo "================================="
echo -e "${BLUE}Login Credentials:${NC}"
echo "Username: admin"
echo "Password: $ARGO_PASSWORD"
echo ""
echo -e "${BLUE}Access Methods:${NC}"
if [ ! -z "$LB_URL" ]; then
    echo "Web UI: http://$LB_URL"
fi
echo "Port Forward: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "Then visit: https://localhost:8080"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "1. Login to ArgoCD UI"
echo "2. Create applications for your microservices"
echo "3. Connect your Git repository"
echo "4. Enable auto-sync for declarative deployments"

# Save credentials to file
echo -e "\n${BLUE}6. Saving credentials...${NC}"
cat > argocd-credentials.txt << EOF
ArgoCD Access Information
========================

Web UI: http://$LB_URL
Username: admin
Password: $ARGO_PASSWORD

Port Forward Command:
kubectl port-forward svc/argocd-server -n argocd 8080:443

Local URL: https://localhost:8080

Installation Date: $(date)
EOF

echo -e "${GREEN}[✓]${NC} Credentials saved to argocd-credentials.txt"
