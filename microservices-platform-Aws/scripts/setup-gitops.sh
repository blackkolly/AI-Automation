#!/bin/bash

# GitOps Setup Script
# Initializes the GitOps environment for the microservices platform

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🚀 Microservices Platform GitOps Setup${NC}"
echo "========================================="

# Check if running on GitHub Actions
if [ "$GITHUB_ACTIONS" = "true" ]; then
    echo -e "${BLUE}[INFO]${NC} Running in GitHub Actions environment"
    
    # Configure git for GitHub Actions
    git config --global user.name "GitHub Actions Bot"
    git config --global user.email "actions@github.com"
else
    echo -e "${BLUE}[INFO]${NC} Running in local environment"
fi

# Function to check command availability
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}[ERROR]${NC} $1 is not installed. Please install it first."
        return 1
    else
        echo -e "${GREEN}[✓]${NC} $1 is available"
        return 0
    fi
}

# Check prerequisites
echo -e "\n${BLUE}Checking prerequisites...${NC}"
MISSING_TOOLS=0

check_command "kubectl" || MISSING_TOOLS=$((MISSING_TOOLS + 1))
check_command "aws" || MISSING_TOOLS=$((MISSING_TOOLS + 1))
check_command "docker" || MISSING_TOOLS=$((MISSING_TOOLS + 1))
check_command "git" || MISSING_TOOLS=$((MISSING_TOOLS + 1))

if [ $MISSING_TOOLS -gt 0 ]; then
    echo -e "${RED}[ERROR]${NC} Please install missing tools before proceeding."
    exit 1
fi

# AWS Configuration
echo -e "\n${BLUE}Configuring AWS access...${NC}"

if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo -e "${YELLOW}[WARNING]${NC} AWS credentials not found in environment variables."
    echo "Please ensure AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are set."
    
    if [ "$GITHUB_ACTIONS" != "true" ]; then
        echo "You can configure AWS credentials by running: aws configure"
    fi
fi

# Configure kubectl for EKS
echo -e "\n${BLUE}Configuring kubectl for EKS...${NC}"
AWS_REGION=${AWS_REGION:-"us-east-1"}
EKS_CLUSTER=${EKS_CLUSTER:-"microservices-platform-prod"}

if aws eks update-kubeconfig --region $AWS_REGION --name $EKS_CLUSTER 2>/dev/null; then
    echo -e "${GREEN}[✓]${NC} kubectl configured for EKS cluster: $EKS_CLUSTER"
    
    # Test cluster connectivity
    if kubectl cluster-info &> /dev/null; then
        echo -e "${GREEN}[✓]${NC} Successfully connected to Kubernetes cluster"
        
        # Show cluster information
        echo -e "\n${BLUE}Cluster Information:${NC}"
        kubectl get nodes --no-headers | wc -l | xargs -I {} echo "Nodes: {}"
        kubectl get namespaces --no-headers | wc -l | xargs -I {} echo "Namespaces: {}"
    else
        echo -e "${YELLOW}[WARNING]${NC} Cannot connect to Kubernetes cluster"
    fi
else
    echo -e "${YELLOW}[WARNING]${NC} Could not configure kubectl for EKS cluster"
fi

# ECR Login
echo -e "\n${BLUE}Logging into ECR...${NC}"
ECR_REGISTRY=${ECR_REGISTRY:-"779066052352.dkr.ecr.us-east-1.amazonaws.com"}

if aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY 2>/dev/null; then
    echo -e "${GREEN}[✓]${NC} Successfully logged into ECR: $ECR_REGISTRY"
else
    echo -e "${YELLOW}[WARNING]${NC} Could not log into ECR"
fi

# Create staging namespace if it doesn't exist
echo -e "\n${BLUE}Setting up namespaces...${NC}"
if kubectl get namespace staging &> /dev/null; then
    echo -e "${GREEN}[✓]${NC} Staging namespace already exists"
else
    if kubectl create namespace staging 2>/dev/null; then
        echo -e "${GREEN}[✓]${NC} Created staging namespace"
    else
        echo -e "${YELLOW}[WARNING]${NC} Could not create staging namespace"
    fi
fi

# Verify deployments exist
echo -e "\n${BLUE}Checking current deployments...${NC}"
SERVICES=("api-gateway" "auth-service" "order-service" "product-service" "frontend")

for service in "${SERVICES[@]}"; do
    if kubectl get deployment $service &> /dev/null; then
        echo -e "${GREEN}[✓]${NC} $service deployment exists"
    else
        echo -e "${YELLOW}[WARNING]${NC} $service deployment not found"
    fi
done

# Make scripts executable
echo -e "\n${BLUE}Setting up scripts...${NC}"
if [ -f "scripts/gitops-deploy.sh" ]; then
    chmod +x scripts/gitops-deploy.sh
    echo -e "${GREEN}[✓]${NC} Made gitops-deploy.sh executable"
fi

# Git setup for GitOps
echo -e "\n${BLUE}Git configuration...${NC}"
if git rev-parse --git-dir &> /dev/null; then
    echo -e "${GREEN}[✓]${NC} Git repository detected"
    
    # Check if we're on main or develop branch
    CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
    echo -e "${BLUE}[INFO]${NC} Current branch: $CURRENT_BRANCH"
    
    if [ "$CURRENT_BRANCH" = "main" ]; then
        echo -e "${GREEN}[✓]${NC} On main branch - commits will trigger production deployment"
    elif [ "$CURRENT_BRANCH" = "develop" ]; then
        echo -e "${GREEN}[✓]${NC} On develop branch - commits will trigger staging deployment"
    else
        echo -e "${YELLOW}[INFO]${NC} On feature branch - commits will trigger testing pipeline"
    fi
else
    echo -e "${YELLOW}[WARNING]${NC} Not in a git repository"
fi

# Summary
echo -e "\n${GREEN}🎉 GitOps setup completed!${NC}"
echo "=============================="
echo ""
echo -e "${BLUE}Available commands:${NC}"
echo "  ./scripts/gitops-deploy.sh setup           - Run this setup again"
echo "  ./scripts/gitops-deploy.sh build <service> - Build and push a service"
echo "  ./scripts/gitops-deploy.sh deploy <service> - Deploy a service"
echo "  ./scripts/gitops-deploy.sh full-deploy     - Deploy all services"
echo "  ./scripts/gitops-deploy.sh health          - Check service health"
echo ""
echo -e "${BLUE}GitHub Actions workflows:${NC}"
echo "  Push to main branch     → Production deployment"
echo "  Push to develop branch  → Staging deployment"
echo "  Manual deployment      → Use GitHub Actions UI"
echo "  Rollback               → Use GitHub Actions UI"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Configure GitHub repository secrets (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)"
echo "2. Push changes to trigger GitOps pipeline"
echo "3. Monitor deployments in GitHub Actions"
echo "4. Use ArgoCD for advanced GitOps features"
echo ""

if [ "$GITHUB_ACTIONS" != "true" ]; then
    echo -e "${YELLOW}[TIP]${NC} Run './scripts/gitops-deploy.sh health' to check current deployment status"
fi
