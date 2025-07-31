#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Installing Security Stack...${NC}"

# Create security namespace
echo -e "${YELLOW}Creating security namespace...${NC}"
kubectl create namespace security --dry-run=client -o yaml | kubectl apply -f -

# Add Helm repositories
echo -e "${YELLOW}Adding Helm repositories...${NC}"
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo add aqua https://aquasecurity.github.io/helm-charts/
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm repo add falco-security https://falcosecurity.github.io/charts
helm repo update

# Install HashiCorp Vault for secrets management
echo -e "${YELLOW}Installing HashiCorp Vault...${NC}"
helm upgrade --install vault hashicorp/vault \
  --namespace security \
  --set server.dev.enabled=true \
  --set server.dev.devRootToken="root" \
  --set ui.enabled=true \
  --set ui.serviceType="LoadBalancer" \
  --wait

# Install Trivy for vulnerability scanning
echo -e "${YELLOW}Installing Trivy Operator...${NC}"
helm upgrade --install trivy-operator aqua/trivy-operator \
  --namespace security \
  --set trivyOperator.scanJobTimeout=5m \
  --set compliance.enabled=true \
  --set rbac.create=true \
  --wait

# Install OPA Gatekeeper for policy enforcement
echo -e "${YELLOW}Installing OPA Gatekeeper...${NC}"
helm upgrade --install gatekeeper gatekeeper/gatekeeper \
  --namespace security \
  --set replicas=3 \
  --set auditInterval=60 \
  --set constraintViolationsLimit=20 \
  --set auditFromCache=false \
  --set enableDeleteOperations=false \
  --wait

# Install Falco for runtime security monitoring
echo -e "${YELLOW}Installing Falco...${NC}"
helm upgrade --install falco falco-security/falco \
  --namespace security \
  --set driver.enabled=true \
  --set ebpf.enabled=false \
  --set auditLog.enabled=true \
  --set falco.grpc.enabled=true \
  --set falco.grpcOutput.enabled=true \
  --set serviceMonitor.enabled=true \
  --wait

# Apply security policies
echo -e "${YELLOW}Applying security policies...${NC}"
kubectl apply -f ./network-policies.yaml
kubectl apply -f ./pod-security-policies.yaml
kubectl apply -f ./gatekeeper-constraints.yaml
kubectl apply -f ./rbac-policies.yaml

# Apply Vault configuration
echo -e "${YELLOW}Configuring Vault...${NC}"
kubectl apply -f ./vault-config.yaml

# Wait for all deployments to be ready
echo -e "${YELLOW}Waiting for deployments to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/vault -n security
kubectl wait --for=condition=available --timeout=300s deployment/trivy-operator -n security
kubectl wait --for=condition=available --timeout=300s deployment/gatekeeper-controller-manager -n security

# Get access information
echo -e "${GREEN}Security stack installation completed!${NC}"
echo -e "${YELLOW}Access Information:${NC}"
echo "Vault UI: kubectl port-forward svc/vault-ui 8200:8200 -n security"
echo "Vault Root Token: root (development only!)"
echo "Trivy: kubectl get vulnerabilityreports -A"
echo "Gatekeeper: kubectl get constraints"
echo "Falco: kubectl logs -l app=falco -n security"

echo -e "${GREEN}Security stack is ready!${NC}"
echo -e "${RED}IMPORTANT: Replace development Vault token with production secrets!${NC}"
