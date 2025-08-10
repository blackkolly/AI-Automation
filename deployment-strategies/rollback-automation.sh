#!/bin/bash

# Comprehensive Rollback Automation System
# Integrates with monitoring, alerting, and deployment strategies

set -e

# Configuration
NAMESPACE="${NAMESPACE:-microservices}"
KUBECTL_CMD="${KUBECTL_CMD:-kubectl}"
MONITORING_INTERVAL=30
ERROR_THRESHOLD=5
CRITICAL_ERROR_THRESHOLD=10
ROLLBACK_DELAY=300
AUTO_ROLLBACK="${AUTO_ROLLBACK:-true}"

# Service configurations
declare -A SERVICES=(
    ["api-gateway"]="api-gateway-service:30000"
    ["auth-service"]="auth-service:30001"
    ["product-service"]="product-service:30002"
    ["order-service"]="order-service:30003"
    ["frontend"]="frontend:30080"
    ["feature-flags-service"]="feature-flags-service:3000"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Logging functions
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

critical() {
    echo -e "${PURPLE}[CRITICAL] $1${NC}"
}

# Create rollback state directory
ROLLBACK_STATE_DIR="/tmp/rollback-automation"
mkdir -p "${ROLLBACK_STATE_DIR}"

# Health check function
health_check() {
    local service="$1"
    local endpoint="${SERVICES[$service]}"
    
    if [[ -z "${endpoint}" ]]; then
        warn "Unknown service: ${service}"
        return 1
    fi
    
    # Extract host and port
    local host="${endpoint%:*}"
    local port="${endpoint#*:}"
    
    # Try to get pod IP if service name is used
    if [[ "${host}" != "localhost" && "${host}" != "127.0.0.1" ]]; then
        local pod_ip
        pod_ip=$(${KUBECTL_CMD} get service "${host}" -n ${NAMESPACE} -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")
        if [[ -n "${pod_ip}" && "${pod_ip}" != "None" ]]; then
            host="${pod_ip}"
        else
            # Get pod IP directly
            pod_ip=$(${KUBECTL_CMD} get pods -n ${NAMESPACE} -l app="${service}" -o jsonpath='{.items[0].status.podIP}' 2>/dev/null || echo "")
            if [[ -n "${pod_ip}" ]]; then
                host="${pod_ip}"
            fi
        fi
    fi
    
    # Perform health check
    local health_path="/health"
    if [[ "${service}" == "frontend" ]]; then
        health_path="/"
    fi
    
    if curl -f -s -m 10 "http://${host}:${port}${health_path}" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Get service metrics
get_service_metrics() {
    local service="$1"
    local endpoint="${SERVICES[$service]}"
    
    if [[ -z "${endpoint}" ]]; then
        echo "unknown"
        return
    fi
    
    # Extract host and port
    local host="${endpoint%:*}"
    local port="${endpoint#*:}"
    
    # Get pod IP
    if [[ "${host}" != "localhost" && "${host}" != "127.0.0.1" ]]; then
        local pod_ip
        pod_ip=$(${KUBECTL_CMD} get service "${host}" -n ${NAMESPACE} -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")
        if [[ -n "${pod_ip}" && "${pod_ip}" != "None" ]]; then
            host="${pod_ip}"
        fi
    fi
    
    # Try to get metrics
    local metrics_path="/metrics"
    local metrics_port="9090"
    
    # For some services, try different metrics endpoints
    case "${service}" in
        "frontend")
            metrics_path="/"
            metrics_port="${port}"
            ;;
        "feature-flags-service")
            metrics_port="9090"
            ;;
    esac
    
    local metrics=""
    if curl -f -s -m 5 "http://${host}:${metrics_port}${metrics_path}" 2>/dev/null | grep -E "(error_rate|response_time|requests_total)" > /dev/null; then
        metrics=$(curl -f -s -m 5 "http://${host}:${metrics_port}${metrics_path}" 2>/dev/null | grep -E "(error_rate|response_time|requests_total)" | head -3)
    fi
    
    echo "${metrics:-no_metrics}"
}

# Save deployment state
save_deployment_state() {
    local service="$1"
    local deployment_type="$2" # blue-green, canary, regular
    
    log "Saving deployment state for ${service} (${deployment_type})"
    
    local state_file="${ROLLBACK_STATE_DIR}/${service}-${deployment_type}-state.json"
    
    # Get current deployment info
    local deployment_info
    deployment_info=$(${KUBECTL_CMD} get deployment "${service}" -n ${NAMESPACE} -o json 2>/dev/null || echo "{}")
    
    # Get current service info
    local service_info
    service_info=$(${KUBECTL_CMD} get service "${service}" -n ${NAMESPACE} -o json 2>/dev/null || echo "{}")
    
    # Get current configmaps
    local configmap_info
    configmap_info=$(${KUBECTL_CMD} get configmaps -n ${NAMESPACE} -l app="${service}" -o json 2>/dev/null || echo "{}")
    
    # Create state snapshot
    local state_snapshot
    state_snapshot=$(cat << EOF
{
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "service": "${service}",
    "deployment_type": "${deployment_type}",
    "deployment": ${deployment_info},
    "service": ${service_info},
    "configmaps": ${configmap_info},
    "health_status": "$(health_check "${service}" && echo "healthy" || echo "unhealthy")",
    "metrics": "$(get_service_metrics "${service}")"
}
EOF
    )
    
    echo "${state_snapshot}" > "${state_file}"
    log "State saved to ${state_file}"
}

# Load deployment state
load_deployment_state() {
    local service="$1"
    local deployment_type="$2"
    
    local state_file="${ROLLBACK_STATE_DIR}/${service}-${deployment_type}-state.json"
    
    if [[ -f "${state_file}" ]]; then
        cat "${state_file}"
    else
        echo "{}"
    fi
}

# Detect deployment issues
detect_issues() {
    local service="$1"
    local duration="${2:-300}" # 5 minutes default
    
    log "Monitoring ${service} for issues (${duration}s)..."
    
    local start_time=$(date +%s)
    local end_time=$((start_time + duration))
    local error_count=0
    local check_count=0
    local consecutive_failures=0
    
    while [[ $(date +%s) -lt ${end_time} ]]; do
        check_count=$((check_count + 1))
        
        # Perform health check
        if ! health_check "${service}"; then
            error_count=$((error_count + 1))
            consecutive_failures=$((consecutive_failures + 1))
            warn "Health check failed for ${service} (failure ${consecutive_failures})"
        else
            consecutive_failures=0
        fi
        
        # Check error rate
        local error_rate=$((error_count * 100 / check_count))
        
        # Log current status
        info "Service: ${service}, Checks: ${check_count}, Errors: ${error_count}, Error Rate: ${error_rate}%, Consecutive Failures: ${consecutive_failures}"
        
        # Check if we should trigger rollback
        if [[ ${error_rate} -gt ${ERROR_THRESHOLD} || ${consecutive_failures} -gt ${CRITICAL_ERROR_THRESHOLD} ]]; then
            critical "Issue detected for ${service}! Error rate: ${error_rate}%, Consecutive failures: ${consecutive_failures}"
            return 1
        fi
        
        sleep ${MONITORING_INTERVAL}
    done
    
    log "Monitoring completed for ${service}. No critical issues detected."
    return 0
}

# Automatic rollback for blue-green deployment
rollback_blue_green() {
    local service="$1"
    local reason="$2"
    
    critical "Initiating blue-green rollback for ${service}. Reason: ${reason}"
    
    # Load previous state
    local previous_state
    previous_state=$(load_deployment_state "${service}" "blue-green")
    
    if [[ "${previous_state}" == "{}" ]]; then
        error "No previous state found for ${service}. Cannot perform automatic rollback."
        return 1
    fi
    
    # Switch traffic back to stable version
    local current_active
    current_active=$(${KUBECTL_CMD} get service "${service}" -n ${NAMESPACE} -o jsonpath='{.spec.selector.version}' 2>/dev/null || echo "")
    
    local rollback_version
    if [[ "${current_active}" == "blue" ]]; then
        rollback_version="green"
    else
        rollback_version="blue"
    fi
    
    log "Switching traffic from ${current_active} to ${rollback_version}"
    
    # Update service selector
    ${KUBECTL_CMD} patch service "${service}" -n ${NAMESPACE} -p "{\"spec\":{\"selector\":{\"version\":\"${rollback_version}\"}}}"
    
    # Wait for traffic switch
    sleep 30
    
    # Verify rollback
    if health_check "${service}"; then
        log "Blue-green rollback successful for ${service}"
        
        # Scale down the problematic version
        ${KUBECTL_CMD} scale deployment "${service}-${current_active}" -n ${NAMESPACE} --replicas=0
        
        return 0
    else
        error "Rollback failed for ${service}. Manual intervention required!"
        return 1
    fi
}

# Automatic rollback for canary deployment
rollback_canary() {
    local service="$1"
    local reason="$2"
    
    critical "Initiating canary rollback for ${service}. Reason: ${reason}"
    
    # Set canary traffic to 0%
    log "Setting canary traffic to 0%"
    
    # Update canary service to route no traffic
    ${KUBECTL_CMD} patch service "${service}-canary" -n ${NAMESPACE} -p '{"spec":{"selector":{"version":"stable"}}}'
    
    # Scale down canary deployment
    ${KUBECTL_CMD} scale deployment "${service}-canary" -n ${NAMESPACE} --replicas=0
    
    # Ensure stable deployment is scaled up
    ${KUBECTL_CMD} scale deployment "${service}-stable" -n ${NAMESPACE} --replicas=3
    
    # Wait for scaling
    ${KUBECTL_CMD} wait --for=condition=available --timeout=300s deployment/"${service}-stable" -n ${NAMESPACE}
    
    # Verify rollback
    if health_check "${service}"; then
        log "Canary rollback successful for ${service}"
        return 0
    else
        error "Canary rollback failed for ${service}. Manual intervention required!"
        return 1
    fi
}

# Automatic rollback for regular deployment
rollback_regular() {
    local service="$1"
    local reason="$2"
    
    critical "Initiating regular rollback for ${service}. Reason: ${reason}"
    
    # Get rollout history
    local revision_count
    revision_count=$(${KUBECTL_CMD} rollout history deployment/"${service}" -n ${NAMESPACE} --format=json | jq '.items | length' 2>/dev/null || echo "0")
    
    if [[ ${revision_count} -lt 2 ]]; then
        error "No previous revision available for ${service}. Cannot rollback."
        return 1
    fi
    
    # Perform rollback
    ${KUBECTL_CMD} rollout undo deployment/"${service}" -n ${NAMESPACE}
    
    # Wait for rollback to complete
    ${KUBECTL_CMD} rollout status deployment/"${service}" -n ${NAMESPACE} --timeout=300s
    
    # Verify rollback
    if health_check "${service}"; then
        log "Regular rollback successful for ${service}"
        return 0
    else
        error "Regular rollback failed for ${service}. Manual intervention required!"
        return 1
    fi
}

# Feature flags rollback
rollback_feature_flags() {
    local flag_name="$1"
    local reason="$2"
    
    critical "Initiating feature flag rollback for ${flag_name}. Reason: ${reason}"
    
    # Check if feature flags service is available
    if ! health_check "feature-flags-service"; then
        error "Feature flags service is not healthy. Cannot perform flag rollback."
        return 1
    fi
    
    # Call feature flags manager script
    local script_path="./feature-flags-manager.sh"
    if [[ -f "${script_path}" ]]; then
        "${script_path}" rollback "${flag_name}" "false" "0"
    else
        # Manual rollback via kubectl
        warn "Feature flags manager script not found. Performing manual rollback..."
        
        # Get current config
        local current_config
        current_config=$(${KUBECTL_CMD} get configmap feature-flags -n ${NAMESPACE} -o jsonpath='{.data.flags\.json}')
        
        # Disable the flag
        local updated_config
        updated_config=$(echo "${current_config}" | jq ".features.${flag_name}.enabled = false | .features.${flag_name}.rollout = 0")
        
        # Update configmap
        local temp_file
        temp_file=$(mktemp)
        echo "${updated_config}" > "${temp_file}"
        
        ${KUBECTL_CMD} create configmap feature-flags --from-file=flags.json="${temp_file}" -n ${NAMESPACE} --dry-run=client -o yaml | ${KUBECTL_CMD} apply -f -
        
        rm -f "${temp_file}"
    fi
    
    log "Feature flag rollback completed for ${flag_name}"
}

# Comprehensive system rollback
system_rollback() {
    local reason="$1"
    
    critical "Initiating comprehensive system rollback. Reason: ${reason}"
    
    # Rollback all services
    for service in "${!SERVICES[@]}"; do
        if [[ "${service}" == "feature-flags-service" ]]; then
            continue # Handle separately
        fi
        
        log "Rolling back ${service}..."
        
        # Determine deployment type
        local deployment_type="regular"
        if ${KUBECTL_CMD} get deployment "${service}-blue" -n ${NAMESPACE} &>/dev/null; then
            deployment_type="blue-green"
        elif ${KUBECTL_CMD} get deployment "${service}-canary" -n ${NAMESPACE} &>/dev/null; then
            deployment_type="canary"
        fi
        
        # Perform appropriate rollback
        case "${deployment_type}" in
            "blue-green")
                rollback_blue_green "${service}" "${reason}"
                ;;
            "canary")
                rollback_canary "${service}" "${reason}"
                ;;
            "regular")
                rollback_regular "${service}" "${reason}"
                ;;
        esac
    done
    
    # Emergency shutdown all feature flags
    if [[ -f "./feature-flags-manager.sh" ]]; then
        ./feature-flags-manager.sh emergency
    fi
    
    log "Comprehensive system rollback completed"
}

# Monitor and auto-rollback
monitor_and_rollback() {
    local service="$1"
    local deployment_type="$2"
    local duration="${3:-600}" # 10 minutes default
    
    log "Starting monitoring and auto-rollback for ${service} (${deployment_type}, ${duration}s)"
    
    # Save current state before monitoring
    save_deployment_state "${service}" "${deployment_type}"
    
    # Monitor for issues
    if ! detect_issues "${service}" "${duration}"; then
        if [[ "${AUTO_ROLLBACK}" == "true" ]]; then
            warn "Issues detected. Triggering automatic rollback..."
            
            case "${deployment_type}" in
                "blue-green")
                    rollback_blue_green "${service}" "Automatic rollback due to health issues"
                    ;;
                "canary")
                    rollback_canary "${service}" "Automatic rollback due to health issues"
                    ;;
                "regular")
                    rollback_regular "${service}" "Automatic rollback due to health issues"
                    ;;
                *)
                    error "Unknown deployment type: ${deployment_type}"
                    ;;
            esac
        else
            error "Issues detected, but auto-rollback is disabled. Manual intervention required!"
            return 1
        fi
    fi
    
    log "Monitoring completed successfully for ${service}"
}

# Monitor all services
monitor_all_services() {
    local duration="${1:-600}"
    
    log "Monitoring all services for ${duration} seconds..."
    
    # Create monitoring PIDs array
    local pids=()
    
    # Start monitoring for each service
    for service in "${!SERVICES[@]}"; do
        if [[ "${service}" == "feature-flags-service" ]]; then
            continue # Monitor separately
        fi
        
        # Determine deployment type
        local deployment_type="regular"
        if ${KUBECTL_CMD} get deployment "${service}-blue" -n ${NAMESPACE} &>/dev/null; then
            deployment_type="blue-green"
        elif ${KUBECTL_CMD} get deployment "${service}-canary" -n ${NAMESPACE} &>/dev/null; then
            deployment_type="canary"
        fi
        
        # Start monitoring in background
        monitor_and_rollback "${service}" "${deployment_type}" "${duration}" &
        pids+=($!)
    done
    
    # Wait for all monitoring processes
    for pid in "${pids[@]}"; do
        wait "${pid}" || warn "Monitoring process ${pid} exited with error"
    done
    
    log "All service monitoring completed"
}

# Setup rollback webhook
setup_webhook() {
    local webhook_port="${1:-8080}"
    
    log "Setting up rollback webhook on port ${webhook_port}..."
    
    # Create simple webhook server
    cat > "${ROLLBACK_STATE_DIR}/webhook-server.js" << 'EOF'
const http = require('http');
const url = require('url');
const { exec } = require('child_process');

const port = process.env.WEBHOOK_PORT || 8080;

const server = http.createServer((req, res) => {
    const parsedUrl = url.parse(req.url, true);
    
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.setHeader('Content-Type', 'application/json');
    
    if (req.method === 'OPTIONS') {
        res.writeHead(200);
        res.end();
        return;
    }
    
    if (req.method === 'POST' && parsedUrl.pathname === '/rollback') {
        let body = '';
        req.on('data', chunk => {
            body += chunk.toString();
        });
        req.on('end', () => {
            try {
                const data = JSON.parse(body);
                const service = data.service;
                const deploymentType = data.deploymentType || 'regular';
                const reason = data.reason || 'Webhook triggered rollback';
                
                console.log(`Webhook rollback requested for ${service} (${deploymentType}): ${reason}`);
                
                // Execute rollback script
                const command = `./rollback-automation.sh rollback-${deploymentType} ${service} "${reason}"`;
                exec(command, (error, stdout, stderr) => {
                    if (error) {
                        console.error(`Rollback failed: ${error}`);
                        res.writeHead(500);
                        res.end(JSON.stringify({
                            success: false,
                            error: error.message
                        }));
                    } else {
                        console.log(`Rollback successful: ${stdout}`);
                        res.writeHead(200);
                        res.end(JSON.stringify({
                            success: true,
                            output: stdout
                        }));
                    }
                });
            } catch (error) {
                res.writeHead(400);
                res.end(JSON.stringify({
                    success: false,
                    error: 'Invalid JSON'
                }));
            }
        });
    } else {
        res.writeHead(404);
        res.end(JSON.stringify({
            error: 'Not Found'
        }));
    }
});

server.listen(port, () => {
    console.log(`Rollback webhook server listening on port ${port}`);
});
EOF
    
    # Start webhook server in background
    cd "${ROLLBACK_STATE_DIR}"
    WEBHOOK_PORT="${webhook_port}" node webhook-server.js &
    local webhook_pid=$!
    echo "${webhook_pid}" > webhook.pid
    
    log "Webhook server started with PID ${webhook_pid}"
}

# Stop webhook
stop_webhook() {
    local webhook_pid_file="${ROLLBACK_STATE_DIR}/webhook.pid"
    
    if [[ -f "${webhook_pid_file}" ]]; then
        local webhook_pid
        webhook_pid=$(cat "${webhook_pid_file}")
        
        if kill "${webhook_pid}" 2>/dev/null; then
            log "Webhook server stopped"
        else
            warn "Failed to stop webhook server or already stopped"
        fi
        
        rm -f "${webhook_pid_file}"
    else
        warn "Webhook PID file not found"
    fi
}

# Show usage
show_usage() {
    cat << EOF
Rollback Automation System

Usage: $0 <command> [options]

Commands:
    monitor <service> <type> [duration]     Monitor service and auto-rollback if issues detected
    monitor-all [duration]                  Monitor all services
    rollback-blue-green <service> [reason]  Rollback blue-green deployment
    rollback-canary <service> [reason]      Rollback canary deployment
    rollback-regular <service> [reason]     Rollback regular deployment
    rollback-flag <flag-name> [reason]      Rollback feature flag
    rollback-system [reason]                Comprehensive system rollback
    health-check <service>                  Check service health
    save-state <service> <type>             Save deployment state
    load-state <service> <type>             Load deployment state
    setup-webhook [port]                    Setup rollback webhook
    stop-webhook                            Stop rollback webhook

Deployment Types:
    blue-green                              Blue-green deployment
    canary                                  Canary deployment
    regular                                 Regular deployment

Environment Variables:
    NAMESPACE                               Kubernetes namespace (default: microservices)
    KUBECTL_CMD                             kubectl command (default: kubectl)
    AUTO_ROLLBACK                           Enable auto-rollback (default: true)
    ERROR_THRESHOLD                         Error rate threshold for rollback (default: 5)
    CRITICAL_ERROR_THRESHOLD                Consecutive failures threshold (default: 10)

Examples:
    $0 monitor api-gateway blue-green 600
    $0 monitor-all 300
    $0 rollback-canary api-gateway "High error rate detected"
    $0 rollback-system "Critical system failure"
    $0 health-check api-gateway
    $0 setup-webhook 8080

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
    
    case "${command}" in
        monitor)
            monitor_and_rollback "$@"
            ;;
        monitor-all)
            monitor_all_services "$@"
            ;;
        rollback-blue-green)
            rollback_blue_green "$@"
            ;;
        rollback-canary)
            rollback_canary "$@"
            ;;
        rollback-regular)
            rollback_regular "$@"
            ;;
        rollback-flag)
            rollback_feature_flags "$@"
            ;;
        rollback-system)
            system_rollback "$@"
            ;;
        health-check)
            if health_check "$1"; then
                log "Service $1 is healthy"
                exit 0
            else
                error "Service $1 is unhealthy"
                exit 1
            fi
            ;;
        save-state)
            save_deployment_state "$@"
            ;;
        load-state)
            load_deployment_state "$@"
            ;;
        setup-webhook)
            setup_webhook "$@"
            ;;
        stop-webhook)
            stop_webhook
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

# Trap signals for cleanup
trap 'stop_webhook' EXIT

# Run main function with all arguments
main "$@"
