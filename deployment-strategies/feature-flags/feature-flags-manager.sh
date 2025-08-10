#!/bin/bash

# Feature Flags Management and Automation Script
# Provides comprehensive feature flag management, A/B testing, and rollback automation

set -e

# Configuration
NAMESPACE="${NAMESPACE:-microservices}"
KUBECTL_CMD="${KUBECTL_CMD:-kubectl}"
SERVICE_NAME="feature-flags-service"
CONFIG_MAP="feature-flags"
MONITORING_INTERVAL=30
ERROR_THRESHOLD=5
ROLLBACK_DELAY=300

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Validate dependencies
validate_dependencies() {
    log "Validating dependencies..."
    
    if ! command -v kubectl &> /dev/null; then
        error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        warn "jq is not installed. Some JSON operations may not work properly"
    fi
    
    # Check cluster connectivity
    if ! ${KUBECTL_CMD} cluster-info &> /dev/null; then
        error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    log "Dependencies validated successfully"
}

# Get feature flag service status
get_service_status() {
    local pod_status
    pod_status=$(${KUBECTL_CMD} get pods -n ${NAMESPACE} -l app=${SERVICE_NAME} --no-headers 2>/dev/null | awk '{print $3}' | head -1)
    
    if [[ "${pod_status}" == "Running" ]]; then
        echo "running"
    else
        echo "stopped"
    fi
}

# Get feature flag service endpoint
get_service_endpoint() {
    local service_ip
    service_ip=$(${KUBECTL_CMD} get service ${SERVICE_NAME} -n ${NAMESPACE} -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
    
    if [[ -n "${service_ip}" && "${service_ip}" != "None" ]]; then
        echo "${service_ip}:3000"
    else
        echo "localhost:3000"
    fi
}

# Deploy feature flags service
deploy_service() {
    log "Deploying feature flags service..."
    
    # Apply the feature flags service manifests
    if [[ -f "feature-flags-service.yaml" ]]; then
        ${KUBECTL_CMD} apply -f feature-flags-service.yaml
    else
        error "feature-flags-service.yaml not found"
        exit 1
    fi
    
    # Wait for deployment to be ready
    log "Waiting for feature flags service to be ready..."
    ${KUBECTL_CMD} wait --for=condition=available --timeout=300s deployment/${SERVICE_NAME} -n ${NAMESPACE}
    
    # Verify service is running
    local endpoint
    endpoint=$(get_service_endpoint)
    
    local retries=0
    local max_retries=30
    
    while [[ ${retries} -lt ${max_retries} ]]; do
        if curl -f -s "http://${endpoint}/health" > /dev/null 2>&1; then
            log "Feature flags service is healthy and responding"
            break
        fi
        
        retries=$((retries + 1))
        info "Waiting for service to be ready... (${retries}/${max_retries})"
        sleep 10
    done
    
    if [[ ${retries} -eq ${max_retries} ]]; then
        error "Feature flags service failed to become ready"
        exit 1
    fi
    
    log "Feature flags service deployed successfully"
}

# List all feature flags
list_flags() {
    log "Listing all feature flags..."
    
    local endpoint
    endpoint=$(get_service_endpoint)
    
    if ! curl -f -s "http://${endpoint}/flags" | jq '.' 2>/dev/null; then
        ${KUBECTL_CMD} get configmap ${CONFIG_MAP} -n ${NAMESPACE} -o jsonpath='{.data.flags\.json}' | jq '.features'
    fi
}

# Get specific feature flag status
get_flag_status() {
    local flag_name="$1"
    local user_id="${2:-default}"
    local environment="${3:-production}"
    local region="${4:-us}"
    local version="${5:-1.0.0}"
    
    if [[ -z "${flag_name}" ]]; then
        error "Flag name is required"
        return 1
    fi
    
    log "Getting status for feature flag: ${flag_name}"
    
    local endpoint
    endpoint=$(get_service_endpoint)
    
    local url="http://${endpoint}/flag/${flag_name}?userId=${user_id}&environment=${environment}&region=${region}&version=${version}"
    
    if ! curl -f -s "${url}" | jq '.'; then
        warn "Failed to get flag status from service, checking ConfigMap..."
        ${KUBECTL_CMD} get configmap ${CONFIG_MAP} -n ${NAMESPACE} -o jsonpath="{.data.flags\.json}" | jq ".features.${flag_name}"
    fi
}

# Update feature flag
update_flag() {
    local flag_name="$1"
    local enabled="$2"
    local rollout="$3"
    
    if [[ -z "${flag_name}" || -z "${enabled}" ]]; then
        error "Flag name and enabled status are required"
        return 1
    fi
    
    log "Updating feature flag: ${flag_name} (enabled: ${enabled}, rollout: ${rollout:-current})"
    
    # Get current configuration
    local current_config
    current_config=$(${KUBECTL_CMD} get configmap ${CONFIG_MAP} -n ${NAMESPACE} -o jsonpath='{.data.flags\.json}')
    
    # Update the flag using jq
    local updated_config
    if [[ -n "${rollout}" ]]; then
        updated_config=$(echo "${current_config}" | jq ".features.${flag_name}.enabled = ${enabled} | .features.${flag_name}.rollout = ${rollout}")
    else
        updated_config=$(echo "${current_config}" | jq ".features.${flag_name}.enabled = ${enabled}")
    fi
    
    # Create temporary file with updated configuration
    local temp_file
    temp_file=$(mktemp)
    echo "${updated_config}" > "${temp_file}"
    
    # Update ConfigMap
    ${KUBECTL_CMD} create configmap ${CONFIG_MAP} --from-file=flags.json="${temp_file}" -n ${NAMESPACE} --dry-run=client -o yaml | ${KUBECTL_CMD} apply -f -
    
    # Clean up
    rm -f "${temp_file}"
    
    # Reload configuration in service
    reload_configuration
    
    log "Feature flag ${flag_name} updated successfully"
}

# Gradual rollout
gradual_rollout() {
    local flag_name="$1"
    local target_percentage="$2"
    local step_size="${3:-10}"
    local step_interval="${4:-60}"
    
    if [[ -z "${flag_name}" || -z "${target_percentage}" ]]; then
        error "Flag name and target percentage are required"
        return 1
    fi
    
    log "Starting gradual rollout for ${flag_name} to ${target_percentage}% (step: ${step_size}%, interval: ${step_interval}s)"
    
    # Get current rollout percentage
    local current_percentage
    current_percentage=$(${KUBECTL_CMD} get configmap ${CONFIG_MAP} -n ${NAMESPACE} -o jsonpath="{.data.flags\.json}" | jq -r ".features.${flag_name}.rollout // 0")
    
    log "Current rollout: ${current_percentage}%"
    
    # Perform gradual rollout
    while [[ ${current_percentage} -lt ${target_percentage} ]]; do
        local next_percentage=$((current_percentage + step_size))
        if [[ ${next_percentage} -gt ${target_percentage} ]]; then
            next_percentage=${target_percentage}
        fi
        
        log "Rolling out to ${next_percentage}%..."
        update_flag "${flag_name}" "true" "${next_percentage}"
        
        # Monitor for errors
        log "Monitoring for ${step_interval} seconds..."
        sleep ${step_interval}
        
        # Check for errors
        if check_rollout_health "${flag_name}"; then
            current_percentage=${next_percentage}
            log "Rollout step successful. Current: ${current_percentage}%"
        else
            error "Health check failed. Rolling back..."
            rollback_flag "${flag_name}"
            return 1
        fi
    done
    
    log "Gradual rollout completed successfully. Final rollout: ${current_percentage}%"
}

# Check rollout health
check_rollout_health() {
    local flag_name="$1"
    
    log "Checking health for feature flag: ${flag_name}"
    
    # Check service health
    local endpoint
    endpoint=$(get_service_endpoint)
    
    if ! curl -f -s "http://${endpoint}/health" > /dev/null; then
        warn "Feature flags service is not healthy"
        return 1
    fi
    
    # Check application metrics (if available)
    # This would typically integrate with your monitoring system
    # For now, we'll simulate basic health checks
    
    local error_count=0
    local check_count=5
    
    for ((i=1; i<=check_count; i++)); do
        if ! curl -f -s "http://${endpoint}/flag/${flag_name}" > /dev/null; then
            error_count=$((error_count + 1))
        fi
        sleep 1
    done
    
    local error_rate=$((error_count * 100 / check_count))
    
    if [[ ${error_rate} -gt 20 ]]; then
        warn "High error rate detected: ${error_rate}%"
        return 1
    fi
    
    log "Health check passed. Error rate: ${error_rate}%"
    return 0
}

# Rollback feature flag
rollback_flag() {
    local flag_name="$1"
    local backup_enabled="${2:-false}"
    local backup_rollout="${3:-0}"
    
    log "Rolling back feature flag: ${flag_name}"
    
    # Disable the flag immediately
    update_flag "${flag_name}" "${backup_enabled}" "${backup_rollout}"
    
    log "Feature flag ${flag_name} rolled back successfully"
}

# Emergency shutdown
emergency_shutdown() {
    log "Initiating emergency shutdown of all feature flags..."
    
    # Get current configuration
    local current_config
    current_config=$(${KUBECTL_CMD} get configmap ${CONFIG_MAP} -n ${NAMESPACE} -o jsonpath='{.data.flags\.json}')
    
    # Disable all flags
    local updated_config
    updated_config=$(echo "${current_config}" | jq '.features | to_entries | map(.value.enabled = false) | from_entries | {features: ., globalSettings: .globalSettings, rollbackSettings: .rollbackSettings}')
    
    # Create temporary file
    local temp_file
    temp_file=$(mktemp)
    echo "${updated_config}" > "${temp_file}"
    
    # Update ConfigMap
    ${KUBECTL_CMD} create configmap ${CONFIG_MAP} --from-file=flags.json="${temp_file}" -n ${NAMESPACE} --dry-run=client -o yaml | ${KUBECTL_CMD} apply -f -
    
    # Clean up
    rm -f "${temp_file}"
    
    # Reload configuration
    reload_configuration
    
    log "Emergency shutdown completed. All feature flags disabled."
}

# Reload configuration
reload_configuration() {
    local endpoint
    endpoint=$(get_service_endpoint)
    
    if curl -f -s "http://${endpoint}/reload" > /dev/null; then
        log "Configuration reloaded successfully"
    else
        warn "Failed to reload configuration via API. Restarting pods..."
        ${KUBECTL_CMD} rollout restart deployment/${SERVICE_NAME} -n ${NAMESPACE}
        ${KUBECTL_CMD} rollout status deployment/${SERVICE_NAME} -n ${NAMESPACE}
    fi
}

# Monitor feature flags
monitor_flags() {
    local duration="${1:-300}"
    
    log "Monitoring feature flags for ${duration} seconds..."
    
    local end_time=$(($(date +%s) + duration))
    
    while [[ $(date +%s) -lt ${end_time} ]]; do
        local endpoint
        endpoint=$(get_service_endpoint)
        
        # Check service health
        if curl -f -s "http://${endpoint}/health" > /dev/null; then
            info "Service is healthy"
        else
            warn "Service health check failed"
        fi
        
        # Display current flag status
        info "Current feature flags status:"
        curl -f -s "http://${endpoint}/flags" | jq -r '.flags | to_entries[] | "\(.key): enabled=\(.value.enabled), rollout=\(.value.rollout)%"' 2>/dev/null || echo "Failed to get flag status"
        
        sleep ${MONITORING_INTERVAL}
    done
    
    log "Monitoring completed"
}

# Create feature flag
create_flag() {
    local flag_name="$1"
    local description="$2"
    local enabled="${3:-false}"
    local rollout="${4:-0}"
    local environments="${5:-development,staging,production}"
    
    if [[ -z "${flag_name}" ]]; then
        error "Flag name is required"
        return 1
    fi
    
    log "Creating feature flag: ${flag_name}"
    
    # Get current configuration
    local current_config
    current_config=$(${KUBECTL_CMD} get configmap ${CONFIG_MAP} -n ${NAMESPACE} -o jsonpath='{.data.flags\.json}')
    
    # Create new flag configuration
    local env_array
    env_array=$(echo "${environments}" | sed 's/,/", "/g' | sed 's/^/["/' | sed 's/$/"]/')
    
    local new_flag="{
        \"enabled\": ${enabled},
        \"rollout\": ${rollout},
        \"description\": \"${description:-New feature flag}\",
        \"environments\": ${env_array},
        \"constraints\": {
            \"userPercentage\": ${rollout},
            \"regions\": [\"us\", \"eu\", \"asia\"],
            \"minVersion\": \"1.0.0\"
        }
    }"
    
    # Add new flag to configuration
    local updated_config
    updated_config=$(echo "${current_config}" | jq ".features.${flag_name} = ${new_flag}")
    
    # Create temporary file
    local temp_file
    temp_file=$(mktemp)
    echo "${updated_config}" > "${temp_file}"
    
    # Update ConfigMap
    ${KUBECTL_CMD} create configmap ${CONFIG_MAP} --from-file=flags.json="${temp_file}" -n ${NAMESPACE} --dry-run=client -o yaml | ${KUBECTL_CMD} apply -f -
    
    # Clean up
    rm -f "${temp_file}"
    
    # Reload configuration
    reload_configuration
    
    log "Feature flag ${flag_name} created successfully"
}

# Delete feature flag
delete_flag() {
    local flag_name="$1"
    
    if [[ -z "${flag_name}" ]]; then
        error "Flag name is required"
        return 1
    fi
    
    log "Deleting feature flag: ${flag_name}"
    
    # Get current configuration
    local current_config
    current_config=$(${KUBECTL_CMD} get configmap ${CONFIG_MAP} -n ${NAMESPACE} -o jsonpath='{.data.flags\.json}')
    
    # Remove flag from configuration
    local updated_config
    updated_config=$(echo "${current_config}" | jq "del(.features.${flag_name})")
    
    # Create temporary file
    local temp_file
    temp_file=$(mktemp)
    echo "${updated_config}" > "${temp_file}"
    
    # Update ConfigMap
    ${KUBECTL_CMD} create configmap ${CONFIG_MAP} --from-file=flags.json="${temp_file}" -n ${NAMESPACE} --dry-run=client -o yaml | ${KUBECTL_CMD} apply -f -
    
    # Clean up
    rm -f "${temp_file}"
    
    # Reload configuration
    reload_configuration
    
    log "Feature flag ${flag_name} deleted successfully"
}

# A/B testing
ab_test() {
    local flag_name="$1"
    local variant_a_percentage="$2"
    local variant_b_percentage="$3"
    local test_duration="${4:-3600}"
    
    if [[ -z "${flag_name}" || -z "${variant_a_percentage}" || -z "${variant_b_percentage}" ]]; then
        error "Flag name and both variant percentages are required"
        return 1
    fi
    
    local total_percentage=$((variant_a_percentage + variant_b_percentage))
    if [[ ${total_percentage} -gt 100 ]]; then
        error "Total percentage cannot exceed 100%"
        return 1
    fi
    
    log "Starting A/B test for ${flag_name} (A: ${variant_a_percentage}%, B: ${variant_b_percentage}%, Duration: ${test_duration}s)"
    
    # Set up initial state
    update_flag "${flag_name}" "true" "${variant_a_percentage}"
    
    # Monitor the test
    local start_time=$(date +%s)
    local end_time=$((start_time + test_duration))
    
    while [[ $(date +%s) -lt ${end_time} ]]; do
        # Check health
        if ! check_rollout_health "${flag_name}"; then
            error "A/B test failed health check. Aborting..."
            rollback_flag "${flag_name}"
            return 1
        fi
        
        local remaining_time=$((end_time - $(date +%s)))
        info "A/B test running. Time remaining: ${remaining_time}s"
        
        sleep ${MONITORING_INTERVAL}
    done
    
    log "A/B test completed successfully"
    
    # Prompt for decision
    echo "A/B test completed. Choose next action:"
    echo "1) Keep variant A (${variant_a_percentage}%)"
    echo "2) Switch to variant B (${variant_b_percentage}%)"
    echo "3) Full rollout (100%)"
    echo "4) Rollback (0%)"
    
    read -p "Enter your choice (1-4): " choice
    
    case ${choice} in
        1)
            log "Keeping variant A configuration"
            ;;
        2)
            log "Switching to variant B"
            update_flag "${flag_name}" "true" "${variant_b_percentage}"
            ;;
        3)
            log "Performing full rollout"
            update_flag "${flag_name}" "true" "100"
            ;;
        4)
            log "Rolling back"
            rollback_flag "${flag_name}"
            ;;
        *)
            warn "Invalid choice. Keeping current configuration"
            ;;
    esac
}

# Show usage
show_usage() {
    cat << EOF
Feature Flags Management Script

Usage: $0 <command> [options]

Commands:
    deploy                          Deploy feature flags service
    list                           List all feature flags
    status <flag-name> [user-id] [env] [region] [version]  Get flag status
    update <flag-name> <enabled> [rollout]  Update feature flag
    create <flag-name> [description] [enabled] [rollout] [environments]  Create feature flag
    delete <flag-name>             Delete feature flag
    rollout <flag-name> <percentage> [step] [interval]  Gradual rollout
    rollback <flag-name> [enabled] [rollout]  Rollback feature flag
    emergency                      Emergency shutdown all flags
    monitor [duration]             Monitor feature flags
    reload                         Reload configuration
    ab-test <flag-name> <a-percent> <b-percent> [duration]  A/B testing

Environment Variables:
    NAMESPACE                      Kubernetes namespace (default: microservices)
    KUBECTL_CMD                    kubectl command (default: kubectl)

Examples:
    $0 deploy
    $0 list
    $0 status analytics user123 production us 1.2.0
    $0 update analytics true 50
    $0 create newFeature "New amazing feature" false 0 "development,staging"
    $0 rollout analytics 80 10 60
    $0 ab-test newFeature 25 25 3600
    $0 monitor 300
    $0 emergency

EOF
}

# Main script logic
main() {
    if [[ $# -eq 0 ]]; then
        show_usage
        exit 1
    fi
    
    local command="$1"
    shift
    
    validate_dependencies
    
    case "${command}" in
        deploy)
            deploy_service
            ;;
        list)
            list_flags
            ;;
        status)
            get_flag_status "$@"
            ;;
        update)
            update_flag "$@"
            ;;
        create)
            create_flag "$@"
            ;;
        delete)
            delete_flag "$@"
            ;;
        rollout)
            gradual_rollout "$@"
            ;;
        rollback)
            rollback_flag "$@"
            ;;
        emergency)
            emergency_shutdown
            ;;
        monitor)
            monitor_flags "$@"
            ;;
        reload)
            reload_configuration
            ;;
        ab-test)
            ab_test "$@"
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            error "Unknown command: ${command}"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
