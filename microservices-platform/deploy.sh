#!/bin/bash

# Production-Grade Microservices Platform Setup Script
# This script automates the deployment of the entire microservices platform

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="microservices-platform"
AWS_REGION="us-west-2"
ENVIRONMENT="dev"

# Functions
print_header() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local missing_tools=()
    
    command -v aws >/dev/null 2>&1 || missing_tools+=("aws-cli")
    command -v kubectl >/dev/null 2>&1 || missing_tools+=("kubectl")
    command -v helm >/dev/null 2>&1 || missing_tools+=("helm")
    command -v terraform >/dev/null 2>&1 || missing_tools+=("terraform")
    command -v docker >/dev/null 2>&1 || missing_tools+=("docker")
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        echo "Please install the missing tools and run this script again."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        print_error "AWS credentials not configured. Run 'aws configure' first."
        exit 1
    fi
    
    print_success "All prerequisites satisfied"
}

setup_terraform_vars() {
    print_header "Setting up Terraform Variables"
    
    if [ ! -f "infrastructure/terraform/terraform.tfvars" ]; then
        cp infrastructure/terraform/terraform.tfvars.example infrastructure/terraform/terraform.tfvars
        print_warning "Created terraform.tfvars from example. Please review and update the values."
        
        # Prompt for required secrets
        echo -e "${YELLOW}Please provide the following secrets:${NC}"
        
        read -s -p "Database password: " DB_PASSWORD
        echo
        read -s -p "Redis auth token: " REDIS_AUTH_TOKEN
        echo
        read -s -p "Grafana admin password: " GRAFANA_PASSWORD
        echo
        read -s -p "ArgoCD admin password: " ARGOCD_PASSWORD
        echo
        
        export TF_VAR_db_password="$DB_PASSWORD"
        export TF_VAR_redis_auth_token="$REDIS_AUTH_TOKEN"
        export TF_VAR_grafana_admin_password="$GRAFANA_PASSWORD"
        export TF_VAR_argocd_admin_password="$ARGOCD_PASSWORD"
        
        print_success "Environment variables set"
    else
        print_success "terraform.tfvars already exists"
    fi
}

deploy_infrastructure() {
    print_header "Deploying AWS Infrastructure"
    
    cd infrastructure/terraform
    
    # Initialize Terraform
    terraform init
    
    # Plan and apply
    terraform plan -out=tfplan
    terraform apply tfplan
    
    # Get outputs
    export EKS_CLUSTER_NAME=$(terraform output -raw cluster_id)
    export RDS_ENDPOINT=$(terraform output -raw rds_endpoint)
    export REDIS_ENDPOINT=$(terraform output -raw redis_endpoint)
    export ECR_REGISTRY=$(terraform output -raw ecr_registry_id).dkr.ecr.$AWS_REGION.amazonaws.com
    
    cd ../..
    
    print_success "Infrastructure deployed successfully"
}

configure_kubectl() {
    print_header "Configuring kubectl"
    
    aws eks update-kubeconfig --region $AWS_REGION --name $EKS_CLUSTER_NAME
    
    # Wait for cluster to be ready
    echo "Waiting for cluster to be ready..."
    kubectl wait --for=condition=Ready nodes --all --timeout=300s
    
    print_success "kubectl configured and cluster is ready"
}

build_and_push_images() {
    print_header "Building and Pushing Container Images"
    
    # Login to ECR
    aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY
    
    # Build and push each service
    for service in auth-service api-gateway product-service order-service; do
        echo "Building $service..."
        cd services/$service
        
        # Build image
        docker build -t $service:latest .
        
        # Tag and push
        docker tag $service:latest $ECR_REGISTRY/$service:latest
        docker push $ECR_REGISTRY/$service:latest
        
        cd ../..
        print_success "$service image built and pushed"
    done
}

update_manifests() {
    print_header "Updating Kubernetes Manifests"
    
    # Update image references
    find kubernetes/manifests -name "*.yaml" -exec sed -i "s|your-account\.dkr\.ecr\.us-west-2\.amazonaws\.com|$ECR_REGISTRY|g" {} \;
    
    # Update ConfigMap with actual endpoints
    sed -i "s|microservices-postgres\.rds\.amazonaws\.com|$RDS_ENDPOINT|g" kubernetes/manifests/config.yaml
    sed -i "s|microservices-redis\.cache\.amazonaws\.com|$REDIS_ENDPOINT|g" kubernetes/manifests/config.yaml
    
    print_success "Manifests updated with actual values"
}

create_secrets() {
    print_header "Creating Kubernetes Secrets"
    
    # Create namespaces first
    kubectl apply -f kubernetes/manifests/namespaces.yaml
    
    # Database secret
    kubectl create secret generic postgres-secret \
        --from-literal=username=postgres \
        --from-literal=password="$TF_VAR_db_password" \
        -n microservices --dry-run=client -o yaml | kubectl apply -f -
    
    # Redis secret
    kubectl create secret generic redis-secret \
        --from-literal=auth-token="$TF_VAR_redis_auth_token" \
        -n microservices --dry-run=client -o yaml | kubectl apply -f -
    
    # JWT secret
    JWT_SECRET=$(openssl rand -base64 32)
    kubectl create secret generic jwt-secret \
        --from-literal=jwt-secret="$JWT_SECRET" \
        -n microservices --dry-run=client -o yaml | kubectl apply -f -
    
    # OAuth secrets (empty for now - user should update)
    kubectl create secret generic oauth-secrets \
        --from-literal=google-client-id="" \
        --from-literal=google-client-secret="" \
        --from-literal=github-client-id="" \
        --from-literal=github-client-secret="" \
        -n microservices --dry-run=client -o yaml | kubectl apply -f -
    
    # ECR registry secret
    kubectl create secret docker-registry ecr-registry-secret \
        --docker-server=$ECR_REGISTRY \
        --docker-username=AWS \
        --docker-password=$(aws ecr get-login-password --region $AWS_REGION) \
        -n microservices --dry-run=client -o yaml | kubectl apply -f -
    
    print_success "Secrets created"
}

deploy_services() {
    print_header "Deploying Microservices"
    
    # Apply configuration
    kubectl apply -f kubernetes/manifests/config.yaml
    
    # Deploy services
    kubectl apply -f kubernetes/manifests/auth-service.yaml
    kubectl apply -f kubernetes/manifests/api-gateway.yaml
    kubectl apply -f kubernetes/manifests/product-service.yaml
    kubectl apply -f kubernetes/manifests/order-service.yaml
    
    # Wait for deployments
    echo "Waiting for deployments to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment --all -n microservices
    
    print_success "All services deployed and ready"
}

install_monitoring() {
    print_header "Installing Monitoring Stack"
    
    chmod +x kubernetes/monitoring/install-monitoring.sh
    ./kubernetes/monitoring/install-monitoring.sh
    
    print_success "Monitoring stack installed"
}

install_security() {
    print_header "Installing Security Stack"
    
    chmod +x kubernetes/security/install-security.sh
    ./kubernetes/security/install-security.sh
    
    print_success "Security stack installed"
}

install_gitops() {
    print_header "Installing GitOps (ArgoCD)"
    
    chmod +x kubernetes/gitops/install-argocd.sh
    ./kubernetes/gitops/install-argocd.sh
    
    print_success "GitOps stack installed"
}

install_service_mesh() {
    print_header "Installing Service Mesh (Istio)"
    
    # Download and install Istio
    if [ ! -d "istio-1.18.2" ]; then
        curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.18.2 sh -
    fi
    
    export PATH=$PWD/istio-1.18.2/bin:$PATH
    
    # Install Istio
    istioctl install --set values.defaultRevision=default -y
    
    # Enable injection for microservices namespace
    kubectl label namespace microservices istio-injection=enabled --overwrite
    
    # Restart deployments to inject sidecars
    kubectl rollout restart deployment -n microservices
    
    print_success "Service mesh installed"
}

verify_deployment() {
    print_header "Verifying Deployment"
    
    echo "Checking pod status..."
    kubectl get pods -A
    
    echo -e "\nChecking services..."
    kubectl get svc -A
    
    echo -e "\nChecking ingress..."
    kubectl get ingress -A
    
    # Test API health
    API_GATEWAY_LB=$(kubectl get svc api-gateway -n microservices -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    if [ ! -z "$API_GATEWAY_LB" ]; then
        echo -e "\nTesting API Gateway health..."
        timeout 30 bash -c "until curl -s http://$API_GATEWAY_LB/health; do sleep 2; done" || print_warning "API Gateway health check timed out"
    fi
    
    print_success "Deployment verification completed"
}

show_access_info() {
    print_header "Access Information"
    
    API_GATEWAY_LB=$(kubectl get svc api-gateway -n microservices -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    
    echo -e "${GREEN}🚀 Deployment completed successfully!${NC}"
    echo
    echo -e "${YELLOW}Access URLs:${NC}"
    echo "API Gateway: http://$API_GATEWAY_LB"
    echo
    echo -e "${YELLOW}Monitoring (use kubectl port-forward):${NC}"
    echo "Prometheus: kubectl port-forward svc/prometheus-stack-kube-prom-prometheus 9090:9090 -n monitoring"
    echo "Grafana: kubectl port-forward svc/prometheus-stack-grafana 3000:80 -n monitoring"
    echo "Jaeger: kubectl port-forward svc/jaeger-query 16686:16686 -n monitoring"
    echo "ArgoCD: kubectl port-forward svc/argocd-server 8080:443 -n gitops"
    echo
    echo -e "${YELLOW}Credentials:${NC}"
    echo "Grafana: admin / $TF_VAR_grafana_admin_password"
    ARGOCD_PASSWORD=$(kubectl -n gitops get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "Check manually")
    echo "ArgoCD: admin / $ARGOCD_PASSWORD"
    echo
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "1. Update OAuth secrets in kubernetes/manifests/config.yaml"
    echo "2. Configure DNS records for your domain"
    echo "3. Set up SSL certificates"
    echo "4. Review and customize monitoring dashboards"
    echo "5. Configure backup policies"
    echo
    echo -e "${BLUE}For detailed information, see docs/DEPLOYMENT.md${NC}"
}

cleanup_on_error() {
    print_error "Deployment failed. Check the logs above for details."
    echo "To clean up resources, run:"
    echo "  kubectl delete namespace microservices monitoring security gitops"
    echo "  cd infrastructure/terraform && terraform destroy"
    exit 1
}

# Main execution
main() {
    trap cleanup_on_error ERR
    
    print_header "🚀 Starting Microservices Platform Deployment"
    
    # Check if user wants to proceed
    echo -e "${YELLOW}This script will deploy a production-grade microservices platform on AWS EKS.${NC}"
    echo -e "${YELLOW}Estimated deployment time: 30-45 minutes${NC}"
    echo -e "${YELLOW}This will create AWS resources that incur costs.${NC}"
    echo
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Deployment cancelled."
        exit 0
    fi
    
    # Execute deployment steps
    check_prerequisites
    setup_terraform_vars
    deploy_infrastructure
    configure_kubectl
    build_and_push_images
    update_manifests
    create_secrets
    deploy_services
    install_monitoring
    install_security
    install_gitops
    install_service_mesh
    verify_deployment
    show_access_info
    
    print_success "🎉 Microservices platform deployment completed successfully!"
}

# Run main function
main "$@"
