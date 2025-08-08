#!/bin/bash

# AWS Kubernetes Resources Cleanup Script
# This script removes all resources created during the Jaeger and microservices deployment

set -e

echo "🧹 Starting AWS Kubernetes resources cleanup..."

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Configuration
OBSERVABILITY_NS="observability"
MICROSERVICES_NS="microservices"

# Function to confirm deletion
confirm_deletion() {
    echo
    print_warning "⚠️  WARNING: This will delete ALL Kubernetes resources including:"
    echo "  • Jaeger tracing system"
    echo "  • All microservices deployments"
    echo "  • LoadBalancers (which may have costs)"
    echo "  • ConfigMaps and Secrets"
    echo "  • Persistent storage (if any)"
    echo
    read -p "Are you sure you want to proceed? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        print_info "Cleanup cancelled by user."
        exit 0
    fi
    
    echo
    print_info "Proceeding with cleanup..."
}

# Delete microservices namespace and all resources
cleanup_microservices() {
    print_step "Cleaning up microservices namespace: $MICROSERVICES_NS"
    
    if kubectl get namespace "$MICROSERVICES_NS" >/dev/null 2>&1; then
        # Delete all resources in the namespace
        print_info "Deleting all resources in $MICROSERVICES_NS namespace..."
        
        # Delete deployments first to avoid graceful shutdown delays
        kubectl delete deployments --all -n "$MICROSERVICES_NS" --grace-period=0 --force 2>/dev/null || true
        
        # Delete services (including LoadBalancers)
        kubectl delete services --all -n "$MICROSERVICES_NS" --grace-period=0 --force 2>/dev/null || true
        
        # Delete configmaps and secrets
        kubectl delete configmaps --all -n "$MICROSERVICES_NS" --grace-period=0 --force 2>/dev/null || true
        kubectl delete secrets --all -n "$MICROSERVICES_NS" --grace-period=0 --force 2>/dev/null || true
        
        # Delete the namespace
        kubectl delete namespace "$MICROSERVICES_NS" --grace-period=0 --force 2>/dev/null || true
        
        print_info "Microservices namespace cleaned up ✓"
    else
        print_warning "Microservices namespace not found, skipping..."
    fi
}

# Delete observability namespace (Jaeger)
cleanup_observability() {
    print_step "Cleaning up observability namespace: $OBSERVABILITY_NS"
    
    if kubectl get namespace "$OBSERVABILITY_NS" >/dev/null 2>&1; then
        # Delete all resources in the namespace
        print_info "Deleting all resources in $OBSERVABILITY_NS namespace..."
        
        # Delete Jaeger deployment
        kubectl delete deployments --all -n "$OBSERVABILITY_NS" --grace-period=0 --force 2>/dev/null || true
        
        # Delete services (including external LoadBalancers)
        kubectl delete services --all -n "$OBSERVABILITY_NS" --grace-period=0 --force 2>/dev/null || true
        
        # Delete configmaps and secrets
        kubectl delete configmaps --all -n "$OBSERVABILITY_NS" --grace-period=0 --force 2>/dev/null || true
        kubectl delete secrets --all -n "$OBSERVABILITY_NS" --grace-period=0 --force 2>/dev/null || true
        
        # Delete any persistent volumes or claims
        kubectl delete pvc --all -n "$OBSERVABILITY_NS" --grace-period=0 --force 2>/dev/null || true
        
        # Delete the namespace
        kubectl delete namespace "$OBSERVABILITY_NS" --grace-period=0 --force 2>/dev/null || true
        
        print_info "Observability namespace cleaned up ✓"
    else
        print_warning "Observability namespace not found, skipping..."
    fi
}

# Clean up any remaining LoadBalancer services across all namespaces
cleanup_loadbalancers() {
    print_step "Checking for remaining LoadBalancer services..."
    
    # Get all LoadBalancer services
    LOADBALANCERS=$(kubectl get services --all-namespaces -o jsonpath='{range .items[?(@.spec.type=="LoadBalancer")]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)
    
    if [ -n "$LOADBALANCERS" ]; then
        print_warning "Found remaining LoadBalancer services:"
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

# Clean up any persistent volumes
cleanup_persistent_volumes() {
    print_step "Checking for persistent volumes..."
    
    # Delete any PVCs that might be stuck
    kubectl get pvc --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}' | while read namespace pvc; do
        if [ -n "$namespace" ] && [ -n "$pvc" ]; then
            print_info "Deleting PVC: $pvc in namespace $namespace"
            kubectl delete pvc "$pvc" -n "$namespace" --grace-period=0 --force 2>/dev/null || true
        fi
    done
    
    # Check for orphaned persistent volumes
    ORPHANED_PVS=$(kubectl get pv -o jsonpath='{range .items[?(@.status.phase=="Available")]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)
    
    if [ -n "$ORPHANED_PVS" ]; then
        print_warning "Found orphaned persistent volumes:"
        echo "$ORPHANED_PVS"
        
        echo "$ORPHANED_PVS" | while read pv; do
            if [ -n "$pv" ]; then
                print_info "Deleting persistent volume: $pv"
                kubectl delete pv "$pv" --grace-period=0 --force 2>/dev/null || true
            fi
        done
    else
        print_info "No orphaned persistent volumes found ✓"
    fi
}

# Wait for LoadBalancers to be fully deleted
wait_for_loadbalancer_deletion() {
    print_step "Waiting for LoadBalancers to be fully deleted from AWS..."
    
    local max_wait=300  # 5 minutes
    local wait_time=0
    
    while [ $wait_time -lt $max_wait ]; do
        REMAINING_LBS=$(kubectl get services --all-namespaces -o jsonpath='{range .items[?(@.spec.type=="LoadBalancer")]}{.metadata.name}{"\n"}{end}' 2>/dev/null | wc -l)
        
        if [ "$REMAINING_LBS" -eq 0 ]; then
            print_info "All LoadBalancers deleted from AWS ✓"
            return 0
        fi
        
        echo "Waiting for LoadBalancers to be deleted... ($wait_time/$max_wait seconds)"
        sleep 10
        wait_time=$((wait_time + 10))
    done
    
    print_warning "Timeout waiting for LoadBalancers to be deleted. Check AWS Console manually."
}

# Final cleanup verification
verify_cleanup() {
    print_step "Verifying cleanup completion..."
    
    # Check for remaining resources
    REMAINING_DEPLOYMENTS=$(kubectl get deployments --all-namespaces 2>/dev/null | wc -l)
    REMAINING_SERVICES=$(kubectl get services --all-namespaces 2>/dev/null | wc -l)
    REMAINING_NAMESPACES=$(kubectl get namespaces | grep -E "(microservices|observability)" | wc -l)
    
    echo "Cleanup Summary:"
    echo "  • Remaining deployments: $REMAINING_DEPLOYMENTS"
    echo "  • Remaining services: $REMAINING_SERVICES"
    echo "  • Target namespaces remaining: $REMAINING_NAMESPACES"
    
    if [ "$REMAINING_NAMESPACES" -eq 0 ]; then
        print_info "✅ All target resources successfully cleaned up!"
    else
        print_warning "⚠️  Some resources may still be cleaning up. Check with kubectl get all --all-namespaces"
    fi
}

# Show current resources before cleanup
show_current_resources() {
    print_step "Current AWS Kubernetes resources:"
    
    echo
    echo "📊 Namespaces:"
    kubectl get namespaces | grep -E "(microservices|observability)" || echo "  No target namespaces found"
    
    echo
    echo "🚀 Deployments:"
    kubectl get deployments --all-namespaces | grep -E "(microservices|observability)" || echo "  No target deployments found"
    
    echo
    echo "🌐 Services (including LoadBalancers):"
    kubectl get services --all-namespaces -o wide | grep -E "(microservices|observability|LoadBalancer)" || echo "  No target services found"
    
    echo
    echo "💾 Persistent Volumes:"
    kubectl get pv 2>/dev/null || echo "  No persistent volumes found"
    
    echo
}

# Emergency cleanup for stuck resources
emergency_cleanup() {
    print_step "Performing emergency cleanup for stuck resources..."
    
    # Force delete any stuck finalizers
    kubectl get namespaces "$MICROSERVICES_NS" -o json 2>/dev/null | \
        jq '.spec.finalizers = []' | \
        kubectl replace --raw "/api/v1/namespaces/$MICROSERVICES_NS/finalize" -f - 2>/dev/null || true
        
    kubectl get namespaces "$OBSERVABILITY_NS" -o json 2>/dev/null | \
        jq '.spec.finalizers = []' | \
        kubectl replace --raw "/api/v1/namespaces/$OBSERVABILITY_NS/finalize" -f - 2>/dev/null || true
        
    print_info "Emergency cleanup completed"
}

# Print cost savings information
print_cost_info() {
    echo
    echo "======================================"
    echo "💰 Cost Impact Summary"
    echo "======================================"
    
    print_info "Resources Deleted:"
    echo "  • LoadBalancer services (saves ~$18-25/month per LB)"
    echo "  • Compute resources (EC2 instances for pods)"
    echo "  • Storage volumes (if any)"
    echo "  • Data transfer costs"
    
    echo
    print_info "💡 Cost Optimization Tips:"
    echo "  • LoadBalancers are the main ongoing cost"
    echo "  • Consider using NodePort + Ingress for cost savings"
    echo "  • Use spot instances for development clusters"
    echo "  • Monitor unused persistent volumes"
    
    echo
    print_warning "⚠️  Don't forget to:"
    echo "  • Check AWS Console for any remaining resources"
    echo "  • Verify ELB/ALB are deleted in EC2 Dashboard"
    echo "  • Review CloudWatch logs retention"
    echo "  • Check for any persistent EBS volumes"
    
    echo
}

# Main cleanup flow
main() {
    echo "🧹 AWS Kubernetes Cleanup Tool"
    echo "================================"
    
    # Show current state
    show_current_resources
    
    # Confirm deletion
    confirm_deletion
    
    # Perform cleanup
    cleanup_microservices
    cleanup_observability
    cleanup_loadbalancers
    cleanup_persistent_volumes
    
    # Wait for AWS resources to be deleted
    wait_for_loadbalancer_deletion
    
    # Verify cleanup
    verify_cleanup
    
    # Show cost impact
    print_cost_info
    
    print_info "🎉 Cleanup completed!"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE_DELETE=true
            shift
            ;;
        --emergency)
            emergency_cleanup
            exit 0
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --force      Skip confirmation prompt"
            echo "  --emergency  Force cleanup stuck resources"
            echo "  --dry-run    Show what would be deleted without actually deleting"
            echo "  --help       Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Override confirmation for force mode
if [ "$FORCE_DELETE" = true ]; then
    confirm_deletion() {
        print_warning "Force mode enabled - skipping confirmation"
    }
fi

# Dry run mode
if [ "$DRY_RUN" = true ]; then
    print_warning "DRY RUN MODE - No resources will be deleted"
    show_current_resources
    echo
    print_info "To actually delete resources, run without --dry-run flag"
    exit 0
fi

# Run main cleanup
main
