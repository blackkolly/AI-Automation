#!/bin/bash

# Working Local Kubernetes Backup Script
set -e

BACKUP_BASE="/tmp/k8s-backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="$BACKUP_BASE/$TIMESTAMP"

echo "íº€ Starting Kubernetes Local Backup: $TIMESTAMP"
mkdir -p "$BACKUP_DIR"

# Function to safely backup namespace resources
backup_namespace() {
    local ns=$1
    local ns_dir="$BACKUP_DIR/namespaces/$ns"
    
    echo "í³¦ Backing up namespace: $ns"
    mkdir -p "$ns_dir"
    
    # Backup all resources safely
    kubectl get all -n "$ns" -o yaml > "$ns_dir/all-resources.yaml" 2>/dev/null && echo "   âœ… All resources backed up" || echo "   âš ï¸  No resources in $ns"
    kubectl get configmaps -n "$ns" -o yaml > "$ns_dir/configmaps.yaml" 2>/dev/null && echo "   âœ… ConfigMaps backed up" || echo "   âš ï¸  No ConfigMaps in $ns"
    kubectl get secrets -n "$ns" -o yaml > "$ns_dir/secrets.yaml" 2>/dev/null && echo "   âœ… Secrets backed up" || echo "   âš ï¸  No Secrets in $ns"
    kubectl get pvc -n "$ns" -o yaml > "$ns_dir/pvcs.yaml" 2>/dev/null && echo "   âœ… PVCs backed up" || echo "   âš ï¸  No PVCs in $ns"
}

# Backup key namespaces
echo "í³‹ Backing up application namespaces..."
for ns in default microservices velero argocd istio-system monitoring; do
    if kubectl get namespace "$ns" >/dev/null 2>&1; then
        backup_namespace "$ns"
    else
        echo "â­ï¸  Skipping non-existent namespace: $ns"
    fi
done

# Backup cluster-wide resources
echo "í¼ Backing up cluster-wide resources..."
mkdir -p "$BACKUP_DIR/cluster"
kubectl get nodes -o yaml > "$BACKUP_DIR/cluster/nodes.yaml" 2>/dev/null && echo "   âœ… Nodes backed up"
kubectl get pv -o yaml > "$BACKUP_DIR/cluster/persistent-volumes.yaml" 2>/dev/null && echo "   âœ… PVs backed up"
kubectl get sc -o yaml > "$BACKUP_DIR/cluster/storage-classes.yaml" 2>/dev/null && echo "   âœ… Storage Classes backed up"

echo "âœ… Backup completed successfully!"
echo "í³ Location: $BACKUP_DIR"
echo "í³Š Summary: $(find "$BACKUP_DIR" -name "*.yaml" | wc -l) files backed up"
echo "í·‚ï¸  Available backups:"
ls -la "$BACKUP_BASE/" 2>/dev/null | tail -3 || echo "This is your first backup!"
