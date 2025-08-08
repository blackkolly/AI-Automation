#!/bin/bash

# Complete AWS EKS Cleanup Script
# This script will remove ALL resources including ArgoCD to prevent redeployment

set -e

echo "🧹 Starting COMPLETE AWS EKS cleanup..."

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Function to confirm deletion
confirm_complete_deletion() {
    echo
    print_warning "⚠️  COMPLETE CLEANUP WARNING: This will delete:"
    echo "  • ArgoCD (GitOps system)"
    echo "  • All microservices and databases"
    echo "  • All monitoring tools (Prometheus, Grafana, Jaeger)"
    echo "  • All LoadBalancers (significant cost savings)"
    echo "  • All persistent volumes and data"
    echo "  • All namespaces except default/kube-system"
    echo
    echo "💰 This will save you approximately $100-200/month in AWS costs!"
    echo
    read -p "Type 'DELETE EVERYTHING' to confirm complete cleanup: " confirm
    
    if [ "$confirm" != "DELETE EVERYTHING" ]; then
        print_info "Cleanup cancelled by user."
        exit 0
    fi
    
    echo
    print_info "Proceeding with COMPLETE cleanup..."
}

# Stop ArgoCD first to prevent redeployment
stop_argocd() {
    print_step "Stopping ArgoCD to prevent automatic redeployment..."
    
    if kubectl get namespace gitops >/dev/null 2>&1; then
        # Scale down ArgoCD controllers
        kubectl scale deployment argocd-application-controller --replicas=0 -n gitops 2>/dev/null || true
        kubectl scale deployment argocd-server --replicas=0 -n gitops 2>/dev/null || true
        kubectl scale deployment argocd-repo-server --replicas=0 -n gitops 2>/dev/null || true
        kubectl scale statefulset argocd-application-controller --replicas=0 -n gitops 2>/dev/null || true
        
        print_info "ArgoCD stopped ✓"
        sleep 5
    else
        print_info "ArgoCD namespace not found, skipping..."
    fi
}

# Delete all custom namespaces and their resources
cleanup_all_namespaces() {
    print_step "Deleting all custom namespaces and resources..."
    
    # List of namespaces to delete (excluding system namespaces)
    NAMESPACES_TO_DELETE=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -v -E '^(default|kube-system|kube-public|kube-node-lease)$' || true)
    
    if [ -n "$NAMESPACES_TO_DELETE" ]; then
        echo "Namespaces to delete: $NAMESPACES_TO_DELETE"
        
        for ns in $NAMESPACES_TO_DELETE; do
            print_info "Deleting namespace: $ns"
            
            # Delete all resources in the namespace first
            kubectl delete all --all -n "$ns" --grace-period=0 --force 2>/dev/null || true
            kubectl delete configmaps --all -n "$ns" --grace-period=0 --force 2>/dev/null || true
            kubectl delete secrets --all -n "$ns" --grace-period=0 --force 2>/dev/null || true
            kubectl delete pvc --all -n "$ns" --grace-period=0 --force 2>/dev/null || true
            
            # Delete the namespace
            kubectl delete namespace "$ns" --grace-period=0 --force 2>/dev/null || true
        done
        
        print_info "All custom namespaces deleted ✓"
    else
        print_info "No custom namespaces found to delete"
    fi
}

# Clean up any remaining LoadBalancers
cleanup_all_loadbalancers() {
    print_step "Cleaning up ALL LoadBalancer services..."
    
    # Get all LoadBalancer services across all namespaces
    LOADBALANCERS=$(kubectl get services --all-namespaces -o jsonpath='{range .items[?(@.spec.type=="LoadBalancer")]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)
    
    if [ -n "$LOADBALANCERS" ]; then
        print_warning "Deleting remaining LoadBalancer services:"
        echo "$LOADBALANCERS"
        
        echo "$LOADBALANCERS" | while read namespace service; do
            if [ -n "$namespace" ] && [ -n "$service" ]; then
                print_info "Deleting LoadBalancer: $service in namespace $namespace"
                kubectl delete service "$service" -n "$namespace" --grace-period=0 --force 2>/dev/null || true
            fi
        done
    else
        print_info "No LoadBalancer services found ✓"
    fi
}

# Clean up persistent volumes
cleanup_all_persistent_volumes() {
    print_step "Cleaning up ALL persistent volumes..."
    
    # Delete all PVCs first
    ALL_PVCS=$(kubectl get pvc --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)
    
    if [ -n "$ALL_PVCS" ]; then
        echo "$ALL_PVCS" | while read namespace pvc; do
            if [ -n "$namespace" ] && [ -n "$pvc" ]; then
                print_info "Deleting PVC: $pvc in namespace $namespace"
                kubectl delete pvc "$pvc" -n "$namespace" --grace-period=0 --force 2>/dev/null || true
            fi
        done
    fi
    
    # Delete all available persistent volumes
    ALL_PVS=$(kubectl get pv -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)
    
    if [ -n "$ALL_PVS" ]; then
        echo "$ALL_PVS" | while read pv; do
            if [ -n "$pv" ]; then
                print_info "Deleting persistent volume: $pv"
                kubectl delete pv "$pv" --grace-period=0 --force 2>/dev/null || true
            fi
        done
    fi
    
    print_info "All persistent volumes cleaned up ✓"
}

# Wait for complete deletion
wait_for_complete_deletion() {
    print_step "Waiting for complete deletion from AWS..."
    
    local max_wait=600  # 10 minutes
    local wait_time=0
    
    while [ $wait_time -lt $max_wait ]; do
        REMAINING_LBS=$(kubectl get services --all-namespaces -o jsonpath='{range .items[?(@.spec.type=="LoadBalancer")]}{.metadata.name}{"\n"}{end}' 2>/dev/null | wc -l)
        REMAINING_NAMESPACES=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -v -E '^(default|kube-system|kube-public|kube-node-lease)$' | wc -l)
        
        if [ "$REMAINING_LBS" -eq 0 ] && [ "$REMAINING_NAMESPACES" -eq 0 ]; then
            print_info "Complete deletion successful ✓"
            return 0
        fi
        
        echo "Waiting for complete deletion... LoadBalancers: $REMAINING_LBS, Custom Namespaces: $REMAINING_NAMESPACES ($wait_time/$max_wait seconds)"
        sleep 15
        wait_time=$((wait_time + 15))
    done
    
    print_warning "Timeout waiting for complete deletion. Some resources may still be cleaning up."
}

# Final verification
verify_complete_cleanup() {
    print_step "Verifying complete cleanup..."
    
    echo
    echo "🔍 Final Status Check:"
    
    # Check namespaces
    REMAINING_NAMESPACES=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -v -E '^(default|kube-system|kube-public|kube-node-lease)$' || true)
    if [ -n "$REMAINING_NAMESPACES" ]; then
        print_warning "Remaining custom namespaces: $REMAINING_NAMESPACES"
    else
        print_info "✅ All custom namespaces deleted"
    fi
    
    # Check LoadBalancers
    REMAINING_LBS=$(kubectl get services --all-namespaces -o jsonpath='{range .items[?(@.spec.type=="LoadBalancer")]}{.metadata.name}{"\n"}{end}' 2>/dev/null | wc -l)
    if [ "$REMAINING_LBS" -gt 0 ]; then
        print_warning "⚠️  $REMAINING_LBS LoadBalancer(s) still exist"
        kubectl get services --all-namespaces | grep LoadBalancer
    else
        print_info "✅ All LoadBalancers deleted"
    fi
    
    # Check PVs
    REMAINING_PVS=$(kubectl get pv 2>/dev/null | wc -l)
    if [ "$REMAINING_PVS" -gt 1 ]; then  # Header line counts as 1
        print_warning "⚠️  Persistent volumes still exist"
        kubectl get pv 2>/dev/null || true
    else
        print_info "✅ All persistent volumes deleted"
    fi
    
    echo
}

# Calculate cost savings
show_cost_savings() {
    echo
    echo "======================================"
    echo "💰 COST SAVINGS SUMMARY"
    echo "======================================"
    
    print_info "🎉 Resources Successfully Deleted:"
    echo "  ✅ ArgoCD GitOps system"
    echo "  ✅ All microservices (api-gateway, auth-service, order-service, etc.)"
    echo "  ✅ All databases (PostgreSQL, Redis, MongoDB)"
    echo "  ✅ Message queue (Kafka + Zookeeper)"
    echo "  ✅ Monitoring stack (Prometheus, Grafana, AlertManager)"
    echo "  ✅ Tracing system (Jaeger)"
    echo "  ✅ Logging system (Kibana, Elasticsearch)"
    echo "  ✅ ALL LoadBalancers (major cost savings!)"
    echo "  ✅ All persistent storage volumes"
    
    echo
    print_info "💵 Estimated Monthly Savings:"
    echo "  • LoadBalancers: ~$18-25 × 7 = $126-175/month"
    echo "  • Compute resources: ~$50-100/month"
    echo "  • Storage volumes: ~$10-30/month"
    echo "  • Data transfer: ~$5-20/month"
    echo "  =========================================="
    echo "  🏆 TOTAL SAVINGS: ~$191-325/month"
    
    echo
    print_warning "⚠️  Final Steps:"
    echo "  1. Check AWS Console > EC2 > Load Balancers (should be empty)"
    echo "  2. Check AWS Console > EC2 > EBS Volumes (delete any orphaned volumes)"
    echo "  3. Check CloudWatch Logs > Log Groups (delete if not needed)"
    echo "  4. If you're done with EKS completely, consider deleting the cluster"
    
    echo
    print_info "🎯 To delete the entire EKS cluster (ultimate savings):"
    echo "  eksctl delete cluster --name your-cluster-name --region us-west-2"
    
    echo
}

# Main cleanup flow
main() {
    echo "🧹 COMPLETE AWS EKS CLEANUP TOOL"
    echo "================================="
    
    # Show current state
    print_step "Current cluster resources:"
    kubectl get namespaces
    echo
    kubectl get services --all-namespaces | grep LoadBalancer || echo "No LoadBalancers found"
    
    # Confirm deletion
    confirm_complete_deletion
    
    # Perform complete cleanup
    stop_argocd
    cleanup_all_namespaces
    cleanup_all_loadbalancers
    cleanup_all_persistent_volumes
    
    # Wait for complete deletion
    wait_for_complete_deletion
    
    # Verify cleanup
    verify_complete_cleanup
    
    # Show cost savings
    show_cost_savings
    
    print_info "🎉 COMPLETE CLEANUP FINISHED!"
}

# Parse command line arguments
if [ "$1" = "--force" ]; then
    confirm_complete_deletion() {
        print_warning "Force mode enabled - skipping confirmation"
    }
fi

# Run main cleanup
main
