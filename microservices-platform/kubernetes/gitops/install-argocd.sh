#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Installing ArgoCD for GitOps...${NC}"

# Create gitops namespace
echo -e "${YELLOW}Creating gitops namespace...${NC}"
kubectl create namespace gitops --dry-run=client -o yaml | kubectl apply -f -

# Add ArgoCD Helm repository
echo -e "${YELLOW}Adding ArgoCD Helm repository...${NC}"
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install ArgoCD
echo -e "${YELLOW}Installing ArgoCD...${NC}"
helm upgrade --install argocd argo/argo-cd \
  --namespace gitops \
  --set server.service.type=LoadBalancer \
  --set server.extraArgs[0]="--insecure" \
  --set configs.secret.argocdServerAdminPassword='$2a$12$hBwbRANAe4jG3dgyHGHOh.aLBEwrM9Qp8RyZNMPEfSfCgHKHOG.q2' \
  --set configs.repositories.microservices-platform.url=https://github.com/your-org/microservices-platform.git \
  --set configs.repositories.microservices-platform.type=git \
  --set server.config.repositories[0].url=https://github.com/your-org/microservices-platform.git \
  --set server.config.repositories[0].type=git \
  --wait

# Wait for ArgoCD to be ready
echo -e "${YELLOW}Waiting for ArgoCD to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n gitops

# Apply ArgoCD applications
echo -e "${YELLOW}Creating ArgoCD applications...${NC}"
kubectl apply -f ./argocd-applications.yaml

# Apply RBAC configuration
echo -e "${YELLOW}Applying RBAC configuration...${NC}"
kubectl apply -f ./argocd-rbac.yaml

# Get ArgoCD admin password
echo -e "${YELLOW}Getting ArgoCD admin password...${NC}"
ARGOCD_PASSWORD=$(kubectl -n gitops get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# Get LoadBalancer URL
echo -e "${YELLOW}Getting ArgoCD URL...${NC}"
ARGOCD_URL=$(kubectl get svc argocd-server -n gitops -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo -e "${GREEN}ArgoCD installation completed!${NC}"
echo -e "${YELLOW}Access Information:${NC}"
echo "ArgoCD URL: https://${ARGOCD_URL}"
echo "Username: admin"
echo "Password: ${ARGOCD_PASSWORD}"
echo ""
echo "Local access: kubectl port-forward svc/argocd-server 8080:443 -n gitops"
echo "Then visit: https://localhost:8080"

# Install ArgoCD CLI (optional)
echo -e "${YELLOW}To install ArgoCD CLI, run:${NC}"
echo "curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64"
echo "sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd"
echo "rm argocd-linux-amd64"

echo -e "${GREEN}GitOps setup is ready!${NC}"
