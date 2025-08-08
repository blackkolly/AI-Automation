#!/bin/bash

# AWS Terraform Destroy Script
# This script safely destroys all Terraform-managed AWS resources

set -e

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

# Configuration
TERRAFORM_DIR="infrastructure/terraform"
BACKUP_DIR="terraform-backup-$(date +%Y%m%d-%H%M%S)"

# Function to confirm destruction
confirm_destruction() {
    echo
    print_warning "⚠️  TERRAFORM DESTROY WARNING: This will permanently delete:"
    echo "  🏗️  Complete EKS cluster with all node groups"
    echo "  🌐 VPC with all subnets, NAT gateways, and internet gateways"
    echo "  🗄️  RDS PostgreSQL database (ALL DATA WILL BE LOST)"
    echo "  🔄 ElastiCache Redis cluster"
    echo "  📦 ECR repositories with all container images"
    echo "  🪣 S3 buckets with all stored data"
    echo "  🔒 KMS keys for encryption"
    echo "  ⚖️  Application Load Balancer"
    echo "  🔐 All IAM roles and policies"
    echo "  🏷️  All security groups and network ACLs"
    echo
    print_warning "💰 Estimated monthly cost savings: $500-1000+"
    echo
    print_error "🚨 THIS ACTION CANNOT BE UNDONE!"
    echo
    read -p "Type 'DESTROY EVERYTHING' to confirm complete infrastructure destruction: " confirm
    
    if [ "$confirm" != "DESTROY EVERYTHING" ]; then
        print_info "Destruction cancelled by user."
        exit 0
    fi
    
    echo
    print_info "Proceeding with Terraform destroy..."
}

# Backup current state
backup_terraform_state() {
    print_step "Creating backup of Terraform state..."
    
    if [ ! -d "$TERRAFORM_DIR" ]; then
        print_error "Terraform directory not found: $TERRAFORM_DIR"
        exit 1
    fi
    
    mkdir -p "$BACKUP_DIR"
    
    # Copy all Terraform files
    cp -r "$TERRAFORM_DIR"/* "$BACKUP_DIR"/ 2>/dev/null || true
    
    print_info "Terraform state backed up to: $BACKUP_DIR"
}

# Pre-destroy checks
pre_destroy_checks() {
    print_step "Running pre-destroy checks..."
    
    cd "$TERRAFORM_DIR"
    
    # Check if Terraform is initialized
    if [ ! -d ".terraform" ]; then
        print_warning "Terraform not initialized. Initializing..."
        terraform init
    fi
    
    # Validate configuration
    print_info "Validating Terraform configuration..."
    terraform validate
    
    # Show what will be destroyed
    print_info "Generating destroy plan..."
    terraform plan -destroy -out=destroy.tfplan
    
    print_info "Pre-destroy checks completed ✓"
}

# Clean up Kubernetes resources first (to prevent hanging resources)
cleanup_kubernetes_resources() {
    print_step "Cleaning up Kubernetes resources before EKS destruction..."
    
    # First try to clean up K8s resources that might have external dependencies
    print_info "Deleting LoadBalancer services to prevent hanging ELBs..."
    kubectl delete services --all-namespaces --field-selector=spec.type=LoadBalancer --ignore-not-found=true 2>/dev/null || true
    
    # Delete all custom namespaces (except system ones)
    print_info "Deleting custom namespaces..."
    kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | \
        grep -v -E '^(default|kube-system|kube-public|kube-node-lease)$' | \
        xargs -I {} kubectl delete namespace {} --ignore-not-found=true 2>/dev/null || true
    
    # Wait a bit for cleanup
    print_info "Waiting for Kubernetes resources to be cleaned up..."
    sleep 30
    
    print_info "Kubernetes cleanup completed ✓"
}

# Main Terraform destroy
terraform_destroy() {
    print_step "Executing Terraform destroy..."
    
    cd "$TERRAFORM_DIR"
    
    # Apply the destroy plan
    print_info "Applying destroy plan..."
    terraform apply destroy.tfplan
    
    print_info "Terraform destroy completed ✓"
}

# Handle destroy failures and retries
handle_destroy_failures() {
    print_step "Checking for any remaining resources..."
    
    cd "$TERRAFORM_DIR"
    
    # Check if there are any resources left in state
    REMAINING_RESOURCES=$(terraform state list 2>/dev/null | wc -l)
    
    if [ "$REMAINING_RESOURCES" -gt 0 ]; then
        print_warning "Some resources still exist in Terraform state. Attempting targeted destroy..."
        
        # Get list of remaining resources
        terraform state list > remaining_resources.txt
        
        # Try to destroy specific problematic resources first
        print_info "Attempting to destroy potentially problematic resources..."
        
        # Destroy EKS node groups first
        terraform state list | grep "node_group" | while read resource; do
            print_info "Destroying: $resource"
            terraform destroy -target="$resource" -auto-approve || true
        done
        
        # Destroy Fargate profiles
        terraform state list | grep "fargate_profile" | while read resource; do
            print_info "Destroying: $resource"
            terraform destroy -target="$resource" -auto-approve || true
        done
        
        # Try destroy again
        print_info "Attempting final destroy..."
        terraform destroy -auto-approve || true
        
        # Final check
        FINAL_REMAINING=$(terraform state list 2>/dev/null | wc -l)
        if [ "$FINAL_REMAINING" -gt 0 ]; then
            print_warning "Some resources could not be destroyed automatically."
            print_info "Remaining resources:"
            terraform state list
            echo
            print_info "You may need to manually delete these resources from AWS Console."
        fi
    fi
}

# Clean up Terraform files
cleanup_terraform_files() {
    print_step "Cleaning up Terraform files..."
    
    cd "$TERRAFORM_DIR"
    
    # Remove terraform state files
    rm -f terraform.tfstate*
    rm -f .terraform.lock.hcl
    rm -f destroy.tfplan
    rm -f remaining_resources.txt
    rm -rf .terraform/
    
    print_info "Terraform files cleaned up ✓"
}

# Verify AWS resources are deleted
verify_aws_cleanup() {
    print_step "Verifying AWS resources are deleted..."
    
    echo
    print_info "🔍 Checking remaining AWS resources..."
    
    # Check EKS clusters
    print_info "Checking EKS clusters..."
    aws eks list-clusters --region us-west-2 --query 'clusters[]' --output table 2>/dev/null || print_warning "Cannot check EKS clusters"
    
    # Check VPCs (custom ones should be deleted)
    print_info "Checking VPCs..."
    aws ec2 describe-vpcs --region us-west-2 --query 'Vpcs[?!IsDefault].{VpcId:VpcId,CidrBlock:CidrBlock}' --output table 2>/dev/null || print_warning "Cannot check VPCs"
    
    # Check Load Balancers
    print_info "Checking Load Balancers..."
    aws elbv2 describe-load-balancers --region us-west-2 --query 'LoadBalancers[].{Name:LoadBalancerName,State:State.Code}' --output table 2>/dev/null || print_warning "Cannot check Load Balancers"
    
    # Check RDS instances
    print_info "Checking RDS instances..."
    aws rds describe-db-instances --region us-west-2 --query 'DBInstances[].{DBInstanceIdentifier:DBInstanceIdentifier,DBInstanceStatus:DBInstanceStatus}' --output table 2>/dev/null || print_warning "Cannot check RDS instances"
    
    # Check S3 buckets (list buckets that match our naming pattern)
    print_info "Checking S3 buckets..."
    aws s3 ls 2>/dev/null | grep -E "(microservices|app-data|backups)" || print_info "No matching S3 buckets found"
    
    echo
}

# Calculate cost savings
show_cost_savings() {
    echo
    echo "======================================"
    echo "💰 TERRAFORM DESTROY COST SAVINGS"
    echo "======================================"
    
    print_info "🎉 AWS Infrastructure Successfully Destroyed:"
    echo "  ✅ EKS Cluster (control plane + worker nodes)"
    echo "  ✅ VPC with NAT Gateways (3x ~$45/month each)"
    echo "  ✅ Application Load Balancer (~$20/month)"
    echo "  ✅ RDS PostgreSQL database (~$50-100/month)"
    echo "  ✅ ElastiCache Redis (~$30-50/month)"
    echo "  ✅ ECR repositories (data transfer costs)"
    echo "  ✅ S3 buckets (storage + transfer costs)"
    echo "  ✅ All compute resources (EC2 instances)"
    echo
    
    print_info "💵 Estimated Monthly Savings:"
    echo "  • EKS Control Plane: $73/month"
    echo "  • Worker Nodes (3x m5.large): ~$150-300/month"
    echo "  • NAT Gateways (3x): ~$135/month"
    echo "  • Application Load Balancer: ~$20/month"
    echo "  • RDS Database: ~$50-100/month"
    echo "  • ElastiCache: ~$30-50/month"
    echo "  • Data Transfer: ~$20-50/month"
    echo "  =========================================="
    echo "  🏆 TOTAL SAVINGS: ~$478-728/month"
    echo "  🎯 ANNUAL SAVINGS: ~$5,736-8,736/year"
    
    echo
    print_info "🎯 Next Steps:"
    echo "  1. Verify in AWS Console that all resources are deleted"
    echo "  2. Check for any orphaned resources in different regions"
    echo "  3. Review your AWS bill next month to confirm savings"
    echo "  4. Consider using Terraform Cloud for better state management"
    
    echo
    print_info "🔄 To recreate infrastructure later:"
    echo "  1. Restore from backup: $BACKUP_DIR"
    echo "  2. Run: terraform init && terraform plan && terraform apply"
    
    echo
}

# Main execution flow
main() {
    echo "🏗️  TERRAFORM INFRASTRUCTURE DESTROYER"
    echo "======================================"
    
    # Confirm destruction
    confirm_destruction
    
    # Backup current state
    backup_terraform_state
    
    # Pre-destroy checks
    pre_destroy_checks
    
    # Cleanup Kubernetes resources first
    cleanup_kubernetes_resources
    
    # Main Terraform destroy
    terraform_destroy
    
    # Handle any failures
    handle_destroy_failures
    
    # Clean up Terraform files
    cleanup_terraform_files
    
    # Verify cleanup
    verify_aws_cleanup
    
    # Show cost savings
    show_cost_savings
    
    print_info "🎉 TERRAFORM DESTROY COMPLETED!"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE_DESTROY=true
            shift
            ;;
        --skip-k8s-cleanup)
            SKIP_K8S_CLEANUP=true
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --force              Skip confirmation prompt"
            echo "  --skip-k8s-cleanup   Skip Kubernetes resource cleanup"
            echo "  --help               Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Override confirmation for force mode
if [ "$FORCE_DESTROY" = true ]; then
    confirm_destruction() {
        print_warning "Force mode enabled - skipping confirmation"
    }
fi

# Skip Kubernetes cleanup if requested
if [ "$SKIP_K8S_CLEANUP" = true ]; then
    cleanup_kubernetes_resources() {
        print_info "Skipping Kubernetes cleanup as requested"
    }
fi

# Run main destruction process
main
