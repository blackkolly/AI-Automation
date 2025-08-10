#!/bin/bash

# =================================================================
# BLUE-GREEN DEPLOYMENT AUTOMATION SCRIPT
# =================================================================
# This script automates blue-green deployments for microservices
# =================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

NAMESPACE="microservices"
SERVICE_NAME="api-gateway"
CURRENT_VERSION=""
NEW_VERSION=""
DEPLOYMENT_TIMEOUT=300

echo -e "${BLUE}🔄 BLUE-GREEN DEPLOYMENT AUTOMATION${NC}"
echo "===================================="
echo ""

# Function to get current active version
get_active_version() {
    local service_selector=$(kubectl get service ${SERVICE_NAME}-active -n ${NAMESPACE} -o jsonpath='{.spec.selector.version}' 2>/dev/null)
    echo $service_selector
}

# Function to get standby version
get_standby_version() {
    local active_version=$(get_active_version)
    if [ "$active_version" = "blue" ]; then
        echo "green"
    else
        echo "blue"
    fi
}

# Function to health check
health_check() {
    local version=$1
    local service="${SERVICE_NAME}-${version}"
    
    echo -e "${YELLOW}🏥 Health checking ${version} environment...${NC}"
    
    # Port forward to test the service
    kubectl port-forward -n ${NAMESPACE} deployment/${SERVICE_NAME}-${version} 8080:3000 &
    local pf_pid=$!
    
    sleep 5
    
    # Health check
    local health_status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health 2>/dev/null)
    
    # Kill port forward
    kill $pf_pid 2>/dev/null
    wait $pf_pid 2>/dev/null
    
    if [ "$health_status" = "200" ]; then
        echo -e "${GREEN}✅ ${version} environment is healthy${NC}"
        return 0
    else
        echo -e "${RED}❌ ${version} environment health check failed (HTTP: $health_status)${NC}"
        return 1
    fi
}

# Function to switch traffic
switch_traffic() {
    local from_version=$1
    local to_version=$2
    
    echo -e "${PURPLE}🔀 Switching traffic from ${from_version} to ${to_version}...${NC}"
    
    # Update active service to point to new version
    kubectl patch service ${SERVICE_NAME}-active -n ${NAMESPACE} -p '{"spec":{"selector":{"version":"'${to_version}'"}}}'
    
    # Update standby service to point to old version
    kubectl patch service ${SERVICE_NAME}-standby -n ${NAMESPACE} -p '{"spec":{"selector":{"version":"'${from_version}'"}}}'
    
    # Update service annotations
    kubectl annotate service ${SERVICE_NAME}-active -n ${NAMESPACE} active.version=${to_version} --overwrite
    kubectl annotate service ${SERVICE_NAME}-standby -n ${NAMESPACE} standby.version=${from_version} --overwrite
    
    echo -e "${GREEN}✅ Traffic switched to ${to_version} environment${NC}"
}

# Function to scale deployment
scale_deployment() {
    local version=$1
    local replicas=$2
    
    echo -e "${CYAN}📈 Scaling ${SERVICE_NAME}-${version} to ${replicas} replicas...${NC}"
    kubectl scale deployment ${SERVICE_NAME}-${version} -n ${NAMESPACE} --replicas=${replicas}
    
    # Wait for rollout
    kubectl rollout status deployment/${SERVICE_NAME}-${version} -n ${NAMESPACE} --timeout=${DEPLOYMENT_TIMEOUT}s
    
    echo -e "${GREEN}✅ ${SERVICE_NAME}-${version} scaled to ${replicas} replicas${NC}"
}

# Function to deploy new version
deploy_new_version() {
    local new_version=$1
    
    echo -e "${BLUE}🚀 Deploying new version to ${new_version} environment...${NC}"
    
    # Scale up the new version
    scale_deployment $new_version 3
    
    # Wait a bit for pods to be ready
    sleep 10
    
    # Health check the new version
    if health_check $new_version; then
        echo -e "${GREEN}✅ New version deployment successful${NC}"
        return 0
    else
        echo -e "${RED}❌ New version deployment failed${NC}"
        return 1
    fi
}

# Function to rollback
rollback() {
    local current_version=$1
    local previous_version=$2
    
    echo -e "${RED}🔙 Rolling back from ${current_version} to ${previous_version}...${NC}"
    
    # Switch traffic back
    switch_traffic $current_version $previous_version
    
    # Scale down failed version
    scale_deployment $current_version 0
    
    echo -e "${GREEN}✅ Rollback completed${NC}"
}

# Function to validate deployment
validate_deployment() {
    local version=$1
    
    echo -e "${YELLOW}🔍 Validating ${version} deployment...${NC}"
    
    # Check if pods are running
    local running_pods=$(kubectl get pods -n ${NAMESPACE} -l app=${SERVICE_NAME},version=${version} --field-selector=status.phase=Running --no-headers | wc -l)
    
    if [ $running_pods -eq 0 ]; then
        echo -e "${RED}❌ No running pods for ${version} version${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ ${running_pods} pods running for ${version} version${NC}"
    
    # Performance test
    echo -e "${YELLOW}⚡ Running performance test...${NC}"
    kubectl port-forward -n ${NAMESPACE} service/${SERVICE_NAME}-active 8080:3000 &
    local pf_pid=$!
    
    sleep 3
    
    # Simple load test
    for i in {1..10}; do
        local response_time=$(curl -s -w "%{time_total}" -o /dev/null http://localhost:8080/health 2>/dev/null)
        echo "Request $i: ${response_time}s"
    done
    
    kill $pf_pid 2>/dev/null
    wait $pf_pid 2>/dev/null
    
    echo -e "${GREEN}✅ Performance test completed${NC}"
    return 0
}

# Main deployment function
main() {
    echo -e "${PURPLE}🎯 Starting Blue-Green Deployment Process${NC}"
    echo "=========================================="
    echo ""
    
    # Get current state
    CURRENT_VERSION=$(get_active_version)
    NEW_VERSION=$(get_standby_version)
    
    if [ -z "$CURRENT_VERSION" ]; then
        echo -e "${RED}❌ Could not determine current active version${NC}"
        exit 1
    fi
    
    echo -e "${CYAN}Current Active: ${CURRENT_VERSION}${NC}"
    echo -e "${CYAN}Deploying To: ${NEW_VERSION}${NC}"
    echo ""
    
    # Deploy new version
    if deploy_new_version $NEW_VERSION; then
        echo ""
        echo -e "${YELLOW}🔄 Proceeding with traffic switch...${NC}"
        
        # Switch traffic
        switch_traffic $CURRENT_VERSION $NEW_VERSION
        
        # Validate new deployment
        if validate_deployment $NEW_VERSION; then
            echo ""
            echo -e "${GREEN}🎉 Blue-Green deployment successful!${NC}"
            echo -e "${CYAN}Active Version: ${NEW_VERSION}${NC}"
            echo -e "${CYAN}Standby Version: ${CURRENT_VERSION}${NC}"
            
            # Scale down old version (keep 1 replica for quick rollback)
            scale_deployment $CURRENT_VERSION 1
            
            echo ""
            echo -e "${BLUE}📊 Deployment Summary:${NC}"
            echo "• New version deployed and validated"
            echo "• Traffic switched successfully"
            echo "• Old version kept as standby"
            echo "• Ready for next deployment cycle"
            
        else
            echo -e "${RED}❌ Validation failed, rolling back...${NC}"
            rollback $NEW_VERSION $CURRENT_VERSION
            exit 1
        fi
        
    else
        echo -e "${RED}❌ Deployment failed, keeping current version${NC}"
        scale_deployment $NEW_VERSION 0
        exit 1
    fi
}

# Script options
case "${1:-deploy}" in
    "deploy")
        main
        ;;
    "status")
        echo -e "${BLUE}📊 Blue-Green Deployment Status${NC}"
        echo "================================"
        echo ""
        echo -e "${CYAN}Active Version: $(get_active_version)${NC}"
        echo -e "${CYAN}Standby Version: $(get_standby_version)${NC}"
        echo ""
        kubectl get deployments -n ${NAMESPACE} -l app=${SERVICE_NAME}
        echo ""
        kubectl get services -n ${NAMESPACE} -l app=${SERVICE_NAME}
        ;;
    "rollback")
        CURRENT_VERSION=$(get_active_version)
        PREVIOUS_VERSION=$(get_standby_version)
        echo -e "${RED}🔙 Manual Rollback Initiated${NC}"
        rollback $CURRENT_VERSION $PREVIOUS_VERSION
        ;;
    "health")
        CURRENT_VERSION=$(get_active_version)
        health_check $CURRENT_VERSION
        ;;
    "help")
        echo -e "${BLUE}Blue-Green Deployment Script${NC}"
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  deploy   - Deploy new version (default)"
        echo "  status   - Show current deployment status"
        echo "  rollback - Rollback to previous version"
        echo "  health   - Health check active version"
        echo "  help     - Show this help"
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac
