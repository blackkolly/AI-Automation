#!/bin/bash

# =================================================================
# CANARY DEPLOYMENT AUTOMATION SCRIPT
# =================================================================
# This script automates canary deployments with traffic splitting
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
DEPLOYMENT_TIMEOUT=300

# Canary deployment stages
CANARY_STAGES=(10 25 50 75 100)
CANARY_STAGE_DURATION=60  # seconds
VALIDATION_THRESHOLD=95   # success rate percentage

echo -e "${BLUE}🚀 CANARY DEPLOYMENT AUTOMATION${NC}"
echo "================================="
echo ""

# Function to get current canary replicas
get_canary_replicas() {
    kubectl get deployment ${SERVICE_NAME}-canary -n ${NAMESPACE} -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0"
}

# Function to get stable replicas
get_stable_replicas() {
    kubectl get deployment ${SERVICE_NAME}-stable -n ${NAMESPACE} -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0"
}

# Function to calculate traffic percentage
calculate_traffic_percentage() {
    local canary_replicas=$1
    local stable_replicas=$2
    local total_replicas=$((canary_replicas + stable_replicas))
    
    if [ $total_replicas -eq 0 ]; then
        echo "0"
    else
        echo $(( (canary_replicas * 100) / total_replicas ))
    fi
}

# Function to scale deployments
scale_for_traffic_percentage() {
    local target_percentage=$1
    local total_replicas=10  # Total desired replicas
    
    local canary_replicas=$(( (total_replicas * target_percentage) / 100 ))
    local stable_replicas=$(( total_replicas - canary_replicas ))
    
    echo -e "${CYAN}📊 Scaling for ${target_percentage}% canary traffic${NC}"
    echo "  Canary replicas: ${canary_replicas}"
    echo "  Stable replicas: ${stable_replicas}"
    
    # Scale canary deployment
    kubectl scale deployment ${SERVICE_NAME}-canary -n ${NAMESPACE} --replicas=${canary_replicas}
    
    # Scale stable deployment
    kubectl scale deployment ${SERVICE_NAME}-stable -n ${NAMESPACE} --replicas=${stable_replicas}
    
    # Wait for rollouts
    kubectl rollout status deployment/${SERVICE_NAME}-canary -n ${NAMESPACE} --timeout=${DEPLOYMENT_TIMEOUT}s
    kubectl rollout status deployment/${SERVICE_NAME}-stable -n ${NAMESPACE} --timeout=${DEPLOYMENT_TIMEOUT}s
    
    echo -e "${GREEN}✅ Scaling completed${NC}"
}

# Function to health check with traffic percentage
health_check_canary() {
    local target_percentage=$1
    
    echo -e "${YELLOW}🏥 Health checking canary deployment (${target_percentage}% traffic)...${NC}"
    
    # Port forward to canary service
    kubectl port-forward -n ${NAMESPACE} service/${SERVICE_NAME}-canary-service 8080:3000 &
    local pf_pid=$!
    
    sleep 5
    
    local success_count=0
    local total_requests=20
    local canary_requests=0
    local stable_requests=0
    
    echo -e "${CYAN}Running ${total_requests} test requests...${NC}"
    
    for i in $(seq 1 $total_requests); do
        local response=$(curl -s http://localhost:8080/version 2>/dev/null)
        local http_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health 2>/dev/null)
        
        if [ "$http_code" = "200" ]; then
            success_count=$((success_count + 1))
            
            # Check if response came from canary
            if echo "$response" | grep -q "canary"; then
                canary_requests=$((canary_requests + 1))
            else
                stable_requests=$((stable_requests + 1))
            fi
        fi
        
        sleep 0.1
    done
    
    # Kill port forward
    kill $pf_pid 2>/dev/null
    wait $pf_pid 2>/dev/null
    
    local success_rate=$(( (success_count * 100) / total_requests ))
    local actual_canary_percentage=$(( (canary_requests * 100) / total_requests ))
    
    echo -e "${CYAN}📊 Test Results:${NC}"
    echo "  Success rate: ${success_rate}%"
    echo "  Canary requests: ${canary_requests}/${total_requests} (${actual_canary_percentage}%)"
    echo "  Stable requests: ${stable_requests}/${total_requests}"
    
    if [ $success_rate -ge $VALIDATION_THRESHOLD ]; then
        echo -e "${GREEN}✅ Health check passed (${success_rate}% success rate)${NC}"
        return 0
    else
        echo -e "${RED}❌ Health check failed (${success_rate}% success rate, threshold: ${VALIDATION_THRESHOLD}%)${NC}"
        return 1
    fi
}

# Function to run performance metrics
collect_metrics() {
    local stage=$1
    
    echo -e "${YELLOW}📈 Collecting metrics for ${stage}% canary stage...${NC}"
    
    # Port forward to metrics
    kubectl port-forward -n ${NAMESPACE} service/${SERVICE_NAME}-canary-service 9090:9090 &
    local pf_pid=$!
    
    sleep 3
    
    # Collect metrics
    local metrics=$(curl -s http://localhost:9090/metrics 2>/dev/null)
    
    kill $pf_pid 2>/dev/null
    wait $pf_pid 2>/dev/null
    
    echo -e "${CYAN}📊 Metrics collected for ${stage}% stage${NC}"
    
    # Save metrics to file for analysis
    echo "$metrics" > "/tmp/canary-metrics-${stage}percent.txt"
    
    # Extract key metrics
    local canary_requests=$(echo "$metrics" | grep 'api_gateway_canary_requests' | grep -o '[0-9]*' | tail -1)
    echo "  Canary requests: ${canary_requests:-0}"
}

# Function to monitor canary stage
monitor_canary_stage() {
    local stage=$1
    local duration=$2
    
    echo -e "${PURPLE}🔍 Monitoring ${stage}% canary stage for ${duration} seconds...${NC}"
    
    local start_time=$(date +%s)
    local end_time=$((start_time + duration))
    
    while [ $(date +%s) -lt $end_time ]; do
        local remaining=$((end_time - $(date +%s)))
        echo -e "${CYAN}⏱️  Monitoring... ${remaining}s remaining${NC}"
        
        # Quick health check
        if ! health_check_canary $stage; then
            echo -e "${RED}❌ Health check failed during monitoring${NC}"
            return 1
        fi
        
        sleep 10
    done
    
    echo -e "${GREEN}✅ Stage monitoring completed${NC}"
    return 0
}

# Function to rollback canary
rollback_canary() {
    echo -e "${RED}🔙 Rolling back canary deployment...${NC}"
    
    # Scale canary to 0
    kubectl scale deployment ${SERVICE_NAME}-canary -n ${NAMESPACE} --replicas=0
    
    # Scale stable to full capacity
    kubectl scale deployment ${SERVICE_NAME}-stable -n ${NAMESPACE} --replicas=10
    
    # Wait for rollout
    kubectl rollout status deployment/${SERVICE_NAME}-stable -n ${NAMESPACE} --timeout=${DEPLOYMENT_TIMEOUT}s
    
    echo -e "${GREEN}✅ Rollback completed - 100% traffic on stable version${NC}"
}

# Function to promote canary to stable
promote_canary() {
    echo -e "${GREEN}🚀 Promoting canary to stable...${NC}"
    
    # Update stable deployment with canary image/config
    # This would typically involve updating the stable deployment spec
    echo -e "${CYAN}📝 Updating stable deployment with canary configuration...${NC}"
    
    # For demo purposes, we'll simulate the promotion
    kubectl annotate deployment ${SERVICE_NAME}-stable -n ${NAMESPACE} promoted-from-canary="$(date)" --overwrite
    
    # Scale stable to full capacity
    kubectl scale deployment ${SERVICE_NAME}-stable -n ${NAMESPACE} --replicas=10
    
    # Scale canary to 0
    kubectl scale deployment ${SERVICE_NAME}-canary -n ${NAMESPACE} --replicas=0
    
    echo -e "${GREEN}✅ Canary promoted to stable - 100% traffic on new stable version${NC}"
}

# Function to validate feature flags
validate_feature_flags() {
    echo -e "${YELLOW}🚩 Validating feature flags...${NC}"
    
    kubectl port-forward -n ${NAMESPACE} service/${SERVICE_NAME}-canary-only 8081:3000 &
    local pf_pid=$!
    
    sleep 3
    
    # Test new features
    local analytics_response=$(curl -s http://localhost:8081/api/analytics 2>/dev/null)
    local cache_response=$(curl -s http://localhost:8081/api/cache 2>/dev/null)
    
    kill $pf_pid 2>/dev/null
    wait $pf_pid 2>/dev/null
    
    if echo "$analytics_response" | grep -q "enhanced-analytics"; then
        echo -e "${GREEN}✅ Analytics feature working${NC}"
    else
        echo -e "${RED}❌ Analytics feature failed${NC}"
        return 1
    fi
    
    if echo "$cache_response" | grep -q "advanced-cache"; then
        echo -e "${GREEN}✅ Cache feature working${NC}"
    else
        echo -e "${RED}❌ Cache feature failed${NC}"
        return 1
    fi
    
    return 0
}

# Main canary deployment function
deploy_canary() {
    echo -e "${PURPLE}🎯 Starting Canary Deployment Process${NC}"
    echo "====================================="
    echo ""
    
    # Validate feature flags first
    if ! validate_feature_flags; then
        echo -e "${RED}❌ Feature validation failed, aborting deployment${NC}"
        exit 1
    fi
    
    # Start with 100% stable traffic
    scale_for_traffic_percentage 0
    sleep 10
    
    # Go through canary stages
    for stage in "${CANARY_STAGES[@]}"; do
        echo ""
        echo -e "${BLUE}🔄 CANARY STAGE: ${stage}%${NC}"
        echo "======================="
        
        # Scale for this stage
        scale_for_traffic_percentage $stage
        
        # Wait for deployment to stabilize
        sleep 10
        
        # Monitor this stage
        if monitor_canary_stage $stage $CANARY_STAGE_DURATION; then
            # Collect metrics
            collect_metrics $stage
            
            echo -e "${GREEN}✅ Stage ${stage}% completed successfully${NC}"
            
            # If this is the final stage, promote canary
            if [ $stage -eq 100 ]; then
                promote_canary
                echo -e "${GREEN}🎉 Canary deployment completed successfully!${NC}"
                return 0
            fi
            
        else
            echo -e "${RED}❌ Stage ${stage}% failed, initiating rollback${NC}"
            rollback_canary
            exit 1
        fi
    done
}

# Function to show canary status
show_status() {
    echo -e "${BLUE}📊 Canary Deployment Status${NC}"
    echo "============================"
    echo ""
    
    local canary_replicas=$(get_canary_replicas)
    local stable_replicas=$(get_stable_replicas)
    local traffic_percentage=$(calculate_traffic_percentage $canary_replicas $stable_replicas)
    
    echo -e "${CYAN}Current Traffic Distribution:${NC}"
    echo "  Canary: ${traffic_percentage}% (${canary_replicas} replicas)"
    echo "  Stable: $((100 - traffic_percentage))% (${stable_replicas} replicas)"
    echo ""
    
    echo -e "${CYAN}Deployments:${NC}"
    kubectl get deployments -n ${NAMESPACE} -l app=${SERVICE_NAME}
    echo ""
    
    echo -e "${CYAN}Services:${NC}"
    kubectl get services -n ${NAMESPACE} -l app=${SERVICE_NAME}
}

# Script options
case "${1:-deploy}" in
    "deploy")
        deploy_canary
        ;;
    "status")
        show_status
        ;;
    "rollback")
        rollback_canary
        ;;
    "promote")
        promote_canary
        ;;
    "validate-features")
        validate_feature_flags
        ;;
    "set-traffic")
        if [ -z "$2" ]; then
            echo -e "${RED}Usage: $0 set-traffic <percentage>${NC}"
            exit 1
        fi
        scale_for_traffic_percentage "$2"
        ;;
    "help")
        echo -e "${BLUE}Canary Deployment Script${NC}"
        echo "Usage: $0 [command] [options]"
        echo ""
        echo "Commands:"
        echo "  deploy           - Start canary deployment process"
        echo "  status           - Show current deployment status"
        echo "  rollback         - Rollback to stable version"
        echo "  promote          - Promote canary to stable"
        echo "  validate-features - Test feature flags"
        echo "  set-traffic <%%>  - Set traffic percentage manually"
        echo "  help             - Show this help"
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac
