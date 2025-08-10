#!/bin/bash

# Backup Deployment Script
# This script deploys the complete backup and disaster recovery system

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
NAMESPACE_VELERO="velero"
NAMESPACE_BACKUP_MONITORING="backup-monitoring"
NAMESPACE_MICROSERVICES="microservices"
NAMESPACE_KUBE_SYSTEM="kube-system"

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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    # Check cluster admin permissions
    if ! kubectl auth can-i '*' '*' --all-namespaces &> /dev/null; then
        log_warning "May not have sufficient cluster admin permissions"
    fi
    
    log_success "Prerequisites check completed"
}

# Create namespaces
create_namespaces() {
    log_info "Creating namespaces..."
    
    local namespaces=("$NAMESPACE_VELERO" "$NAMESPACE_BACKUP_MONITORING")
    
    for namespace in "${namespaces[@]}"; do
        if kubectl get namespace "$namespace" &> /dev/null; then
            log_info "Namespace $namespace already exists"
        else
            kubectl create namespace "$namespace"
            log_success "Created namespace $namespace"
        fi
    done
}

# Deploy Velero
deploy_velero() {
    log_info "Deploying Velero..."
    
    # Apply Velero deployment
    kubectl apply -f "$BASE_DIR/velero/velero-deployment.yaml"
    
    # Wait for Velero to be ready
    log_info "Waiting for Velero deployment to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/velero -n "$NAMESPACE_VELERO"
    
    # Apply backup schedules
    kubectl apply -f "$BASE_DIR/velero/backup-schedules.yaml"
    
    log_success "Velero deployed successfully"
}

# Deploy ETCD backup
deploy_etcd_backup() {
    log_info "Deploying ETCD backup..."
    
    # Apply ETCD backup manifests
    kubectl apply -f "$BASE_DIR/etcd-backup/etcd-backup.yaml"
    
    # Check if cronjob is created
    if kubectl get cronjob etcd-backup -n "$NAMESPACE_KUBE_SYSTEM" &> /dev/null; then
        log_success "ETCD backup deployed successfully"
    else
        log_error "Failed to deploy ETCD backup"
        return 1
    fi
}

# Deploy database backup
deploy_database_backup() {
    log_info "Deploying database backup..."
    
    # Apply MongoDB backup manifests
    kubectl apply -f "$BASE_DIR/database-backup/mongodb-backup.yaml"
    
    # Check if cronjob is created
    if kubectl get cronjob mongodb-backup -n "$NAMESPACE_MICROSERVICES" &> /dev/null; then
        log_success "Database backup deployed successfully"
    else
        log_error "Failed to deploy database backup"
        return 1
    fi
}

# Deploy monitoring
deploy_monitoring() {
    log_info "Deploying backup monitoring..."
    
    # Apply monitoring manifests
    kubectl apply -f "$BASE_DIR/monitoring/backup-monitoring.yaml"
    
    # Wait for deployments to be ready
    log_info "Waiting for monitoring components to be ready..."
    kubectl wait --for=condition=available --timeout=180s deployment/backup-metrics-exporter -n "$NAMESPACE_BACKUP_MONITORING"
    kubectl wait --for=condition=available --timeout=180s deployment/backup-dashboard -n "$NAMESPACE_BACKUP_MONITORING"
    
    log_success "Backup monitoring deployed successfully"
}

# Configure storage secrets
configure_storage() {
    log_info "Configuring storage secrets..."
    
    # Check if secrets already exist
    local secrets_exist=true
    
    if ! kubectl get secret cloud-credentials -n "$NAMESPACE_VELERO" &> /dev/null; then
        secrets_exist=false
    fi
    
    if ! kubectl get secret etcd-backup-secret -n "$NAMESPACE_KUBE_SYSTEM" &> /dev/null; then
        secrets_exist=false
    fi
    
    if ! kubectl get secret mongodb-backup-secret -n "$NAMESPACE_MICROSERVICES" &> /dev/null; then
        secrets_exist=false
    fi
    
    if [ "$secrets_exist" = false ]; then
        log_warning "Storage secrets are not configured"
        log_info "Please configure the following secrets:"
        echo ""
        echo "1. Velero cloud credentials:"
        echo "   kubectl create secret generic cloud-credentials \\"
        echo "     --from-file=cloud=/path/to/credentials-velero \\"
        echo "     -n $NAMESPACE_VELERO"
        echo ""
        echo "2. ETCD backup S3 credentials:"
        echo "   kubectl create secret generic etcd-backup-secret \\"
        echo "     --from-literal=aws-access-key-id=YOUR_ACCESS_KEY \\"
        echo "     --from-literal=aws-secret-access-key=YOUR_SECRET_KEY \\"
        echo "     -n $NAMESPACE_KUBE_SYSTEM"
        echo ""
        echo "3. MongoDB backup S3 credentials:"
        echo "   kubectl create secret generic mongodb-backup-secret \\"
        echo "     --from-literal=username=mongodb_user \\"
        echo "     --from-literal=password=mongodb_password \\"
        echo "     --from-literal=aws-access-key-id=YOUR_ACCESS_KEY \\"
        echo "     --from-literal=aws-secret-access-key=YOUR_SECRET_KEY \\"
        echo "     -n $NAMESPACE_MICROSERVICES"
        echo ""
    else
        log_success "Storage secrets are already configured"
    fi
}

# Verify deployment
verify_deployment() {
    log_info "Verifying deployment..."
    
    local errors=0
    
    # Check Velero
    if kubectl get deployment velero -n "$NAMESPACE_VELERO" &> /dev/null; then
        if kubectl get deployment velero -n "$NAMESPACE_VELERO" -o jsonpath='{.status.readyReplicas}' | grep -q "1"; then
            log_success "✓ Velero is running"
        else
            log_error "✗ Velero is not ready"
            errors=$((errors + 1))
        fi
    else
        log_error "✗ Velero deployment not found"
        errors=$((errors + 1))
    fi
    
    # Check ETCD backup
    if kubectl get cronjob etcd-backup -n "$NAMESPACE_KUBE_SYSTEM" &> /dev/null; then
        log_success "✓ ETCD backup CronJob is configured"
    else
        log_error "✗ ETCD backup CronJob not found"
        errors=$((errors + 1))
    fi
    
    # Check MongoDB backup
    if kubectl get cronjob mongodb-backup -n "$NAMESPACE_MICROSERVICES" &> /dev/null; then
        log_success "✓ MongoDB backup CronJob is configured"
    else
        log_error "✗ MongoDB backup CronJob not found"
        errors=$((errors + 1))
    fi
    
    # Check monitoring
    if kubectl get deployment backup-metrics-exporter -n "$NAMESPACE_BACKUP_MONITORING" &> /dev/null; then
        log_success "✓ Backup metrics exporter is running"
    else
        log_error "✗ Backup metrics exporter not found"
        errors=$((errors + 1))
    fi
    
    if kubectl get deployment backup-dashboard -n "$NAMESPACE_BACKUP_MONITORING" &> /dev/null; then
        log_success "✓ Backup dashboard is running"
    else
        log_error "✗ Backup dashboard not found"
        errors=$((errors + 1))
    fi
    
    # Check PVCs
    local pvcs=("etcd-backup-pvc:$NAMESPACE_KUBE_SYSTEM" "mongodb-backup-pvc:$NAMESPACE_MICROSERVICES")
    
    for pvc_info in "${pvcs[@]}"; do
        local pvc_name="${pvc_info%%:*}"
        local pvc_namespace="${pvc_info##*:}"
        
        if kubectl get pvc "$pvc_name" -n "$pvc_namespace" &> /dev/null; then
            local status=$(kubectl get pvc "$pvc_name" -n "$pvc_namespace" -o jsonpath='{.status.phase}')
            if [ "$status" = "Bound" ]; then
                log_success "✓ PVC $pvc_name is bound"
            else
                log_error "✗ PVC $pvc_name is not bound (status: $status)"
                errors=$((errors + 1))
            fi
        else
            log_error "✗ PVC $pvc_name not found in namespace $pvc_namespace"
            errors=$((errors + 1))
        fi
    done
    
    if [ $errors -eq 0 ]; then
        log_success "All components deployed successfully!"
        echo ""
        log_info "Dashboard access:"
        echo "  kubectl port-forward svc/backup-dashboard-service 8080:80 -n $NAMESPACE_BACKUP_MONITORING"
        echo "  Then open: http://localhost:8080"
        echo ""
        log_info "Next steps:"
        echo "  1. Configure storage secrets (see output above)"
        echo "  2. Test backup functionality:"
        echo "     ./backup-dr-manager.sh backup --type=test"
        echo "  3. Monitor backup status:"
        echo "     ./backup-dr-manager.sh status"
    else
        log_error "Deployment completed with $errors errors"
        return 1
    fi
}

# Show help
show_help() {
    echo "Backup Deployment Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --help, -h           Show this help message"
    echo "  --check-only         Only check prerequisites"
    echo "  --velero-only        Deploy only Velero"
    echo "  --etcd-only          Deploy only ETCD backup"
    echo "  --database-only      Deploy only database backup"
    echo "  --monitoring-only    Deploy only monitoring"
    echo "  --skip-verify        Skip deployment verification"
    echo ""
    echo "Examples:"
    echo "  $0                   # Full deployment"
    echo "  $0 --check-only      # Check prerequisites only"
    echo "  $0 --velero-only     # Deploy Velero only"
    echo ""
}

# Main deployment function
main() {
    local check_only=false
    local velero_only=false
    local etcd_only=false
    local database_only=false
    local monitoring_only=false
    local skip_verify=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --check-only)
                check_only=true
                shift
                ;;
            --velero-only)
                velero_only=true
                shift
                ;;
            --etcd-only)
                etcd_only=true
                shift
                ;;
            --database-only)
                database_only=true
                shift
                ;;
            --monitoring-only)
                monitoring_only=true
                shift
                ;;
            --skip-verify)
                skip_verify=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Show banner
    echo "============================================="
    echo "  Backup & Disaster Recovery Deployment"
    echo "============================================="
    echo ""
    
    # Check prerequisites
    check_prerequisites
    
    if [ "$check_only" = true ]; then
        log_success "Prerequisites check completed successfully"
        exit 0
    fi
    
    # Create namespaces
    create_namespaces
    
    # Deploy components based on options
    if [ "$velero_only" = true ]; then
        deploy_velero
    elif [ "$etcd_only" = true ]; then
        deploy_etcd_backup
    elif [ "$database_only" = true ]; then
        deploy_database_backup
    elif [ "$monitoring_only" = true ]; then
        deploy_monitoring
    else
        # Full deployment
        deploy_velero
        deploy_etcd_backup
        deploy_database_backup
        deploy_monitoring
    fi
    
    # Configure storage
    configure_storage
    
    # Verify deployment
    if [ "$skip_verify" != true ]; then
        verify_deployment
    fi
    
    log_success "Deployment completed successfully!"
}

# Run main function with all arguments
main "$@"
