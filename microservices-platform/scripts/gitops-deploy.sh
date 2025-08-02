#!/bin/bash

# GitOps Deployment Script
# This script provides GitOps functionality for the microservices platform

set -e

# Configuration
AWS_REGION=${AWS_REGION:-"us-east-1"}
ECR_REGISTRY=${ECR_REGISTRY:-"779066052352.dkr.ecr.us-east-1.amazonaws.com"}
EKS_CLUSTER=${EKS_CLUSTER:-"microservices-platform-prod"}
NAMESPACE=${NAMESPACE:-"default"}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Functions
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed"
        exit 1
    fi
    
    # Check if aws cli is installed
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed"
        exit 1
    fi
    
    # Check if docker is installed
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi
    
    log_success "All prerequisites are met"
}

configure_kubectl() {
    log_info "Configuring kubectl for EKS cluster..."
    aws eks update-kubeconfig --region $AWS_REGION --name $EKS_CLUSTER
    log_success "kubectl configured successfully"
}

login_ecr() {
    log_info "Logging into AWS ECR..."
    aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY
    log_success "ECR login successful"
}

build_and_push_service() {
    local service=$1
    local tag=${2:-"latest"}
    
    log_info "Building and pushing $service:$tag..."
    
    # Navigate to service directory
    cd services/$service
    
    # Build Docker image
    docker build -t $ECR_REGISTRY/$service:$tag .
    
    # Push to ECR
    docker push $ECR_REGISTRY/$service:$tag
    
    # Tag as latest if not already latest
    if [ "$tag" != "latest" ]; then
        docker tag $ECR_REGISTRY/$service:$tag $ECR_REGISTRY/$service:latest
        docker push $ECR_REGISTRY/$service:latest
    fi
    
    cd - > /dev/null
    log_success "$service:$tag built and pushed successfully"
}

deploy_service() {
    local service=$1
    local tag=${2:-"latest"}
    local namespace=${3:-$NAMESPACE}
    
    log_info "Deploying $service:$tag to namespace $namespace..."
    
    # Update deployment image
    kubectl set image deployment/$service $service=$ECR_REGISTRY/$service:$tag -n $namespace
    
    # Wait for rollout to complete
    kubectl rollout status deployment/$service -n $namespace --timeout=300s
    
    log_success "$service:$tag deployed successfully to $namespace"
}

health_check() {
    local namespace=${1:-$NAMESPACE}
    
    log_info "Performing health check in namespace $namespace..."
    
    # Check pod status
    local failed_pods=$(kubectl get pods -n $namespace --field-selector=status.phase!=Running -o jsonpath='{.items[*].metadata.name}')
    
    if [ -n "$failed_pods" ]; then
        log_warning "Some pods are not running: $failed_pods"
        kubectl get pods -n $namespace
    else
        log_success "All pods are running"
    fi
    
    # Check service endpoints
    kubectl get services -n $namespace
    
    # Test API Gateway health if available
    local lb_url=$(kubectl get service api-gateway -n $namespace -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    
    if [ -n "$lb_url" ]; then
        log_info "Testing LoadBalancer endpoint: $lb_url"
        if curl -f http://$lb_url/health &> /dev/null; then
            log_success "LoadBalancer health check passed"
        else
            log_warning "LoadBalancer health check failed"
        fi
    fi
}

rollback_service() {
    local service=$1
    local namespace=${2:-$NAMESPACE}
    local revision=${3:-""}
    
    log_info "Rolling back $service in namespace $namespace..."
    
    if [ -n "$revision" ]; then
        kubectl rollout undo deployment/$service --to-revision=$revision -n $namespace
    else
        kubectl rollout undo deployment/$service -n $namespace
    fi
    
    kubectl rollout status deployment/$service -n $namespace --timeout=300s
    log_success "$service rollback completed"
}

full_deployment() {
    local tag=${1:-"latest"}
    local namespace=${2:-$NAMESPACE}
    
    log_info "Starting full deployment pipeline..."
    
    # Services to deploy
    local services=("api-gateway" "auth-service" "order-service" "product-service" "frontend")
    
    # Build and push all services
    for service in "${services[@]}"; do
        build_and_push_service $service $tag
    done
    
    # Deploy all services
    for service in "${services[@]}"; do
        deploy_service $service $tag $namespace
    done
    
    # Perform health check
    health_check $namespace
    
    log_success "Full deployment completed successfully"
}

# Main script logic
case "$1" in
    "setup")
        check_prerequisites
        configure_kubectl
        login_ecr
        ;;
    "build")
        if [ -z "$2" ]; then
            log_error "Usage: $0 build <service> [tag]"
            exit 1
        fi
        check_prerequisites
        login_ecr
        build_and_push_service $2 $3
        ;;
    "deploy")
        if [ -z "$2" ]; then
            log_error "Usage: $0 deploy <service> [tag] [namespace]"
            exit 1
        fi
        check_prerequisites
        configure_kubectl
        deploy_service $2 $3 $4
        ;;
    "full-deploy")
        check_prerequisites
        configure_kubectl
        login_ecr
        full_deployment $2 $3
        ;;
    "health")
        check_prerequisites
        configure_kubectl
        health_check $2
        ;;
    "rollback")
        if [ -z "$2" ]; then
            log_error "Usage: $0 rollback <service> [namespace] [revision]"
            exit 1
        fi
        check_prerequisites
        configure_kubectl
        rollback_service $2 $3 $4
        ;;
    *)
        echo "Usage: $0 {setup|build|deploy|full-deploy|health|rollback}"
        echo ""
        echo "Commands:"
        echo "  setup                                    - Setup prerequisites and configure access"
        echo "  build <service> [tag]                   - Build and push a service image"
        echo "  deploy <service> [tag] [namespace]      - Deploy a service to Kubernetes"
        echo "  full-deploy [tag] [namespace]           - Build and deploy all services"
        echo "  health [namespace]                      - Perform health checks"
        echo "  rollback <service> [namespace] [revision] - Rollback a service"
        echo ""
        echo "Examples:"
        echo "  $0 setup"
        echo "  $0 build api-gateway v1.0.0"
        echo "  $0 deploy auth-service latest staging"
        echo "  $0 full-deploy v1.0.0"
        echo "  $0 health staging"
        echo "  $0 rollback order-service default 2"
        exit 1
        ;;
esac
