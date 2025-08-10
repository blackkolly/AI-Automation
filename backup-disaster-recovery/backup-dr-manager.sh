#!/bin/bash

# Comprehensive Backup and Disaster Recovery Manager
# Integrates with existing microservices platform for complete data protection

set -e

# Configuration
NAMESPACE="${NAMESPACE:-microservices}"
KUBECTL_CMD="${KUBECTL_CMD:-kubectl}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

# Backup Configuration
BACKUP_STORAGE_CLASS="${BACKUP_STORAGE_CLASS:-standard}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
VELERO_NAMESPACE="${VELERO_NAMESPACE:-velero}"
ETCD_NAMESPACE="${ETCD_NAMESPACE:-kube-system}"

# AWS Configuration (if using AWS)
AWS_REGION="${AWS_REGION:-us-west-2}"
S3_BUCKET="${S3_BUCKET:-kubernetes-backup-$(date +%s)}"

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

success() {
    echo -e "${PURPLE}[SUCCESS] $1${NC}"
}

# Validate dependencies
validate_dependencies() {
    log "Validating backup and disaster recovery dependencies..."
    
    local missing_deps=()
    
    # Check required commands
    for cmd in kubectl curl jq; do
        if ! command -v "${cmd}" &> /dev/null; then
            missing_deps+=("${cmd}")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        error "Missing dependencies: ${missing_deps[*]}"
        echo "Please install the missing dependencies and try again."
        exit 1
    fi
    
    # Check cluster connectivity
    if ! ${KUBECTL_CMD} cluster-info &> /dev/null; then
        error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    log "Dependencies validated successfully"
}

# Setup Velero for cluster backup
setup_velero() {
    log "Setting up Velero for cluster-wide backup..."
    
    # Create Velero namespace
    ${KUBECTL_CMD} create namespace ${VELERO_NAMESPACE} --dry-run=client -o yaml | ${KUBECTL_CMD} apply -f -
    
    # Deploy Velero manifests
    ${KUBECTL_CMD} apply -f "${SCRIPT_DIR}/velero/"
    
    # Wait for Velero to be ready
    log "Waiting for Velero deployment to be ready..."
    ${KUBECTL_CMD} wait --for=condition=available --timeout=300s deployment/velero -n ${VELERO_NAMESPACE}
    
    success "Velero setup completed"
}

# Setup ETCD backup
setup_etcd_backup() {
    log "Setting up ETCD backup..."
    
    # Deploy ETCD backup manifests
    ${KUBECTL_CMD} apply -f "${SCRIPT_DIR}/etcd-backup/"
    
    # Create backup service account and permissions
    ${KUBECTL_CMD} apply -f - << EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: etcd-backup
  namespace: ${ETCD_NAMESPACE}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: etcd-backup
rules:
- apiGroups: [""]
  resources: ["pods", "pods/exec"]
  verbs: ["get", "list", "create"]
- apiGroups: [""]
  resources: ["persistentvolumes", "persistentvolumeclaims"]
  verbs: ["get", "list", "create", "update"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: etcd-backup
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: etcd-backup
subjects:
- kind: ServiceAccount
  name: etcd-backup
  namespace: ${ETCD_NAMESPACE}
EOF

    success "ETCD backup setup completed"
}

# Setup database backup
setup_database_backup() {
    log "Setting up database backup..."
    
    # Deploy database backup manifests
    ${KUBECTL_CMD} apply -f "${SCRIPT_DIR}/database-backup/"
    
    success "Database backup setup completed"
}

# Create full cluster backup
create_cluster_backup() {
    local backup_name="${1:-cluster-backup-$(date +%Y%m%d-%H%M%S)}"
    local include_namespaces="${2:-microservices,kube-system,default}"
    
    log "Creating cluster backup: ${backup_name}"
    
    # Create Velero backup
    ${KUBECTL_CMD} create -f - << EOF
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: ${backup_name}
  namespace: ${VELERO_NAMESPACE}
spec:
  includedNamespaces:
  - ${include_namespaces//,/\\n  - }
  storageLocation: default
  ttl: 720h0m0s
  includeClusterResources: true
  hooks:
    resources:
    - name: mongodb-backup-hook
      includedNamespaces:
      - ${NAMESPACE}
      labelSelector:
        matchLabels:
          app: mongodb
      pre:
      - exec:
          container: mongodb
          command:
          - /bin/bash
          - -c
          - mongodump --archive=/tmp/mongodb-backup.archive --gzip
      post:
      - exec:
          container: mongodb
          command:
          - /bin/bash
          - -c
          - rm -f /tmp/mongodb-backup.archive
EOF

    # Wait for backup to complete
    log "Waiting for backup to complete..."
    
    local timeout=1800  # 30 minutes
    local elapsed=0
    local interval=30
    
    while [[ ${elapsed} -lt ${timeout} ]]; do
        local status
        status=$(${KUBECTL_CMD} get backup ${backup_name} -n ${VELERO_NAMESPACE} -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
        
        case "${status}" in
            "Completed")
                success "Cluster backup completed: ${backup_name}"
                return 0
                ;;
            "Failed"|"FailedValidation")
                error "Cluster backup failed: ${backup_name}"
                ${KUBECTL_CMD} describe backup ${backup_name} -n ${VELERO_NAMESPACE}
                return 1
                ;;
            "InProgress"|"New")
                info "Backup in progress... (${elapsed}s elapsed)"
                ;;
            *)
                warn "Unknown backup status: ${status}"
                ;;
        esac
        
        sleep ${interval}
        elapsed=$((elapsed + interval))
    done
    
    error "Backup timed out after ${timeout} seconds"
    return 1
}

# Create ETCD backup
create_etcd_backup() {
    local backup_name="${1:-etcd-backup-$(date +%Y%m%d-%H%M%S)}"
    
    log "Creating ETCD backup: ${backup_name}"
    
    # Find ETCD pod
    local etcd_pod
    etcd_pod=$(${KUBECTL_CMD} get pods -n ${ETCD_NAMESPACE} -l component=etcd --no-headers | head -1 | awk '{print $1}')
    
    if [[ -z "${etcd_pod}" ]]; then
        error "ETCD pod not found"
        return 1
    fi
    
    # Create backup job
    ${KUBECTL_CMD} create job ${backup_name} --image=k8s.gcr.io/etcd:3.5.0-0 -n ${ETCD_NAMESPACE} --dry-run=client -o yaml | \
    ${KUBECTL_CMD} patch -f - --type=merge -p='{
        "spec": {
            "template": {
                "spec": {
                    "serviceAccountName": "etcd-backup",
                    "containers": [{
                        "name": "etcd-backup",
                        "image": "k8s.gcr.io/etcd:3.5.0-0",
                        "command": [
                            "/bin/sh",
                            "-c",
                            "ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key snapshot save /backup/etcd-snapshot-$(date +%Y%m%d-%H%M%S).db"
                        ],
                        "volumeMounts": [{
                            "name": "etcd-certs",
                            "mountPath": "/etc/kubernetes/pki/etcd",
                            "readOnly": true
                        }, {
                            "name": "backup-storage",
                            "mountPath": "/backup"
                        }]
                    }],
                    "volumes": [{
                        "name": "etcd-certs",
                        "hostPath": {
                            "path": "/etc/kubernetes/pki/etcd"
                        }
                    }, {
                        "name": "backup-storage",
                        "persistentVolumeClaim": {
                            "claimName": "etcd-backup-pvc"
                        }
                    }],
                    "restartPolicy": "OnFailure"
                }
            }
        }
    }' --dry-run=client -o yaml | ${KUBECTL_CMD} apply -f -
    
    success "ETCD backup job created: ${backup_name}"
}

# Create database backup
create_database_backup() {
    local backup_name="${1:-db-backup-$(date +%Y%m%d-%H%M%S)}"
    
    log "Creating database backup: ${backup_name}"
    
    # MongoDB backup
    if ${KUBECTL_CMD} get pods -n ${NAMESPACE} -l app=mongodb --no-headers | grep -q Running; then
        log "Creating MongoDB backup..."
        
        ${KUBECTL_CMD} create job ${backup_name}-mongodb --image=mongo:5.0 -n ${NAMESPACE} --dry-run=client -o yaml | \
        ${KUBECTL_CMD} patch -f - --type=merge -p='{
            "spec": {
                "template": {
                    "spec": {
                        "containers": [{
                            "name": "mongodb-backup",
                            "image": "mongo:5.0",
                            "command": [
                                "/bin/bash",
                                "-c",
                                "mongodump --host mongodb.microservices.svc.cluster.local:27017 --archive=/backup/mongodb-backup-$(date +%Y%m%d-%H%M%S).archive --gzip"
                            ],
                            "volumeMounts": [{
                                "name": "backup-storage",
                                "mountPath": "/backup"
                            }]
                        }],
                        "volumes": [{
                            "name": "backup-storage",
                            "persistentVolumeClaim": {
                                "claimName": "database-backup-pvc"
                            }
                        }],
                        "restartPolicy": "OnFailure"
                    }
                }
            }
        }' --dry-run=client -o yaml | ${KUBECTL_CMD} apply -f -
    fi
    
    success "Database backup job created: ${backup_name}"
}

# List all backups
list_backups() {
    log "Listing all backups..."
    
    echo ""
    info "=== VELERO CLUSTER BACKUPS ==="
    ${KUBECTL_CMD} get backups -n ${VELERO_NAMESPACE} --no-headers | while read line; do
        echo "  📦 $line"
    done
    
    echo ""
    info "=== ETCD BACKUPS ==="
    ${KUBECTL_CMD} get jobs -n ${ETCD_NAMESPACE} -l job-type=etcd-backup --no-headers 2>/dev/null | while read line; do
        echo "  🗃️  $line"
    done
    
    echo ""
    info "=== DATABASE BACKUPS ==="
    ${KUBECTL_CMD} get jobs -n ${NAMESPACE} -l job-type=database-backup --no-headers 2>/dev/null | while read line; do
        echo "  💾 $line"
    done
    
    echo ""
}

# Restore from backup
restore_from_backup() {
    local backup_name="$1"
    local restore_name="${2:-restore-$(date +%Y%m%d-%H%M%S)}"
    
    if [[ -z "${backup_name}" ]]; then
        error "Backup name is required"
        return 1
    fi
    
    log "Restoring from backup: ${backup_name} as ${restore_name}"
    
    # Create Velero restore
    ${KUBECTL_CMD} create -f - << EOF
apiVersion: velero.io/v1
kind: Restore
metadata:
  name: ${restore_name}
  namespace: ${VELERO_NAMESPACE}
spec:
  backupName: ${backup_name}
  excludedResources:
  - nodes
  - events
  - events.events.k8s.io
  - backups.velero.io
  - restores.velero.io
  - resticrepositories.velero.io
  restorePVs: true
EOF

    # Wait for restore to complete
    log "Waiting for restore to complete..."
    
    local timeout=1800  # 30 minutes
    local elapsed=0
    local interval=30
    
    while [[ ${elapsed} -lt ${timeout} ]]; do
        local status
        status=$(${KUBECTL_CMD} get restore ${restore_name} -n ${VELERO_NAMESPACE} -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
        
        case "${status}" in
            "Completed")
                success "Restore completed: ${restore_name}"
                return 0
                ;;
            "Failed"|"FailedValidation")
                error "Restore failed: ${restore_name}"
                ${KUBECTL_CMD} describe restore ${restore_name} -n ${VELERO_NAMESPACE}
                return 1
                ;;
            "InProgress"|"New")
                info "Restore in progress... (${elapsed}s elapsed)"
                ;;
            *)
                warn "Unknown restore status: ${status}"
                ;;
        esac
        
        sleep ${interval}
        elapsed=$((elapsed + interval))
    done
    
    error "Restore timed out after ${timeout} seconds"
    return 1
}

# Disaster recovery simulation
disaster_recovery_drill() {
    local drill_namespace="dr-drill-$(date +%Y%m%d-%H%M%S)"
    
    log "Starting disaster recovery drill in namespace: ${drill_namespace}"
    
    # Create drill namespace
    ${KUBECTL_CMD} create namespace ${drill_namespace}
    
    # Get latest backup
    local latest_backup
    latest_backup=$(${KUBECTL_CMD} get backups -n ${VELERO_NAMESPACE} --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}' 2>/dev/null)
    
    if [[ -z "${latest_backup}" ]]; then
        error "No backups found for disaster recovery drill"
        return 1
    fi
    
    log "Using backup: ${latest_backup}"
    
    # Create restore to drill namespace
    ${KUBECTL_CMD} create -f - << EOF
apiVersion: velero.io/v1
kind: Restore
metadata:
  name: dr-drill-${drill_namespace}
  namespace: ${VELERO_NAMESPACE}
spec:
  backupName: ${latest_backup}
  namespaceMapping:
    ${NAMESPACE}: ${drill_namespace}
  restorePVs: false
EOF

    log "Disaster recovery drill initiated. Check namespace: ${drill_namespace}"
    success "DR drill completed. Remember to clean up: kubectl delete namespace ${drill_namespace}"
}

# Monitor backup health
monitor_backup_health() {
    local duration="${1:-300}"  # 5 minutes default
    
    log "Monitoring backup system health for ${duration} seconds..."
    
    local end_time=$(($(date +%s) + duration))
    
    while [[ $(date +%s) -lt ${end_time} ]]; do
        echo "=== $(date) ==="
        
        # Check Velero status
        if ${KUBECTL_CMD} get pods -n ${VELERO_NAMESPACE} -l component=velero --no-headers | grep -q Running; then
            info "✅ Velero: Healthy"
        else
            warn "❌ Velero: Unhealthy"
        fi
        
        # Check recent backups
        local recent_backups
        recent_backups=$(${KUBECTL_CMD} get backups -n ${VELERO_NAMESPACE} --field-selector metadata.creationTimestamp>$(date -d '24 hours ago' -u +%Y-%m-%dT%H:%M:%SZ) --no-headers | wc -l)
        
        if [[ ${recent_backups} -gt 0 ]]; then
            info "✅ Recent backups: ${recent_backups} in last 24h"
        else
            warn "⚠️  No recent backups found"
        fi
        
        # Check storage
        local backup_storage
        backup_storage=$(${KUBECTL_CMD} get pvc -A --no-headers | grep backup | wc -l)
        info "💾 Backup storage claims: ${backup_storage}"
        
        echo ""
        sleep 30
    done
    
    success "Backup health monitoring completed"
}

# Cleanup old backups
cleanup_old_backups() {
    local retention_days="${1:-${BACKUP_RETENTION_DAYS}}"
    
    log "Cleaning up backups older than ${retention_days} days..."
    
    # Calculate cutoff date
    local cutoff_date
    cutoff_date=$(date -d "${retention_days} days ago" -u +%Y-%m-%dT%H:%M:%SZ)
    
    # Delete old Velero backups
    ${KUBECTL_CMD} get backups -n ${VELERO_NAMESPACE} --field-selector "metadata.creationTimestamp<${cutoff_date}" --no-headers | while read backup_name _; do
        log "Deleting old backup: ${backup_name}"
        ${KUBECTL_CMD} delete backup ${backup_name} -n ${VELERO_NAMESPACE}
    done
    
    # Cleanup old backup jobs
    ${KUBECTL_CMD} get jobs -A --field-selector "metadata.creationTimestamp<${cutoff_date}" -l job-type=backup --no-headers | while read namespace job_name _; do
        log "Deleting old backup job: ${job_name} in ${namespace}"
        ${KUBECTL_CMD} delete job ${job_name} -n ${namespace}
    done
    
    success "Backup cleanup completed"
}

# Backup status dashboard
backup_status() {
    log "Backup and Disaster Recovery Status Dashboard"
    echo "============================================"
    
    echo ""
    info "📦 VELERO STATUS:"
    if ${KUBECTL_CMD} get deployment velero -n ${VELERO_NAMESPACE} &>/dev/null; then
        ${KUBECTL_CMD} get deployment velero -n ${VELERO_NAMESPACE}
        echo ""
        
        # Recent backups
        info "📅 RECENT BACKUPS (Last 7 days):"
        local week_ago
        week_ago=$(date -d '7 days ago' -u +%Y-%m-%dT%H:%M:%SZ)
        ${KUBECTL_CMD} get backups -n ${VELERO_NAMESPACE} --field-selector "metadata.creationTimestamp>${week_ago}" --sort-by=.metadata.creationTimestamp
    else
        echo "  ❌ Velero not deployed"
    fi
    
    echo ""
    info "🗃️  STORAGE STATUS:"
    ${KUBECTL_CMD} get pvc -A --no-headers | grep backup || echo "  No backup storage found"
    
    echo ""
    info "⚡ BACKUP JOBS:"
    ${KUBECTL_CMD} get jobs -A -l job-type=backup --no-headers | head -10 || echo "  No backup jobs found"
    
    echo ""
    info "📊 CLUSTER RESOURCES:"
    echo "  Namespaces: $(${KUBECTL_CMD} get namespaces --no-headers | wc -l)"
    echo "  Deployments: $(${KUBECTL_CMD} get deployments -A --no-headers | wc -l)"
    echo "  Services: $(${KUBECTL_CMD} get services -A --no-headers | wc -l)"
    echo "  PVCs: $(${KUBECTL_CMD} get pvc -A --no-headers | wc -l)"
    
    echo ""
    success "Status dashboard complete"
}

# Full backup and DR setup
setup_full_backup_dr() {
    log "Setting up complete backup and disaster recovery system..."
    
    # Setup all components
    setup_velero
    setup_etcd_backup
    setup_database_backup
    
    # Create initial backup
    create_cluster_backup "initial-backup-$(date +%Y%m%d-%H%M%S)"
    
    # Setup monitoring
    ${KUBECTL_CMD} apply -f "${SCRIPT_DIR}/monitoring/"
    
    success "Complete backup and disaster recovery system setup completed!"
    backup_status
}

# Show usage
show_usage() {
    cat << EOF
Backup and Disaster Recovery Manager

Usage: $0 <command> [options]

Commands:
    setup                           Setup complete backup and DR system
    setup-velero                   Setup Velero cluster backup
    setup-etcd                     Setup ETCD backup
    setup-database                 Setup database backup
    
    backup-cluster [name] [namespaces]  Create full cluster backup
    backup-etcd [name]             Create ETCD backup
    backup-database [name]         Create database backup
    
    list                           List all backups
    restore <backup-name> [restore-name]  Restore from backup
    
    dr-drill                       Perform disaster recovery drill
    monitor [duration]             Monitor backup system health
    cleanup [retention-days]       Cleanup old backups
    status                         Show backup system status

Environment Variables:
    NAMESPACE                      Application namespace (default: microservices)
    KUBECTL_CMD                    kubectl command (default: kubectl)
    BACKUP_RETENTION_DAYS          Backup retention days (default: 30)
    VELERO_NAMESPACE              Velero namespace (default: velero)
    S3_BUCKET                     S3 bucket for backups

Examples:
    $0 setup
    $0 backup-cluster full-backup microservices,kube-system
    $0 restore full-backup-20250810-120000
    $0 dr-drill
    $0 monitor 600
    $0 cleanup 30
    $0 status

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
        setup)
            setup_full_backup_dr
            ;;
        setup-velero)
            setup_velero
            ;;
        setup-etcd)
            setup_etcd_backup
            ;;
        setup-database)
            setup_database_backup
            ;;
        backup-cluster)
            create_cluster_backup "$@"
            ;;
        backup-etcd)
            create_etcd_backup "$@"
            ;;
        backup-database)
            create_database_backup "$@"
            ;;
        list)
            list_backups
            ;;
        restore)
            restore_from_backup "$@"
            ;;
        dr-drill)
            disaster_recovery_drill
            ;;
        monitor)
            monitor_backup_health "$@"
            ;;
        cleanup)
            cleanup_old_backups "$@"
            ;;
        status)
            backup_status
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
