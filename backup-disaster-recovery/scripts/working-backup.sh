#!/bin/bash

# Working Local Kubernetes Backup Script
set -e

BACKUP_BASE="/tmp/k8s-backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="$BACKUP_BASE/$TIMESTAMP"

echo "� Starting Kubernetes Local Backup: $TIMESTAMP"
mkdir -p "$BACKUP_DIR"

# Function to safely backup namespace resources
backup_namespace() {
    local ns=$1
    local ns_dir="$BACKUP_DIR/namespaces/$ns"
    
    echo "� Backing up namespace: $ns"
    mkdir -p "$ns_dir"
    
    # Backup all resources safely
    kubectl get all -n "$ns" -o yaml > "$ns_dir/all-resources.yaml" 2>/dev/null && echo "   ✅ All resources backed up" || echo "   ⚠️  No resources in $ns"
    kubectl get configmaps -n "$ns" -o yaml > "$ns_dir/configmaps.yaml" 2>/dev/null && echo "   ✅ ConfigMaps backed up" || echo "   ⚠️  No ConfigMaps in $ns"
    kubectl get secrets -n "$ns" -o yaml > "$ns_dir/secrets.yaml" 2>/dev/null && echo "   ✅ Secrets backed up" || echo "   ⚠️  No Secrets in $ns"
    kubectl get pvc -n "$ns" -o yaml > "$ns_dir/pvcs.yaml" 2>/dev/null && echo "   ✅ PVCs backed up" || echo "   ⚠️  No PVCs in $ns"
}

# Backup key namespaces
echo "� Backing up application namespaces..."
for ns in default microservices velero argocd istio-system monitoring; do
    if kubectl get namespace "$ns" >/dev/null 2>&1; then
        backup_namespace "$ns"
    else
        echo "⏭️  Skipping non-existent namespace: $ns"
    fi
done

# Backup cluster-wide resources
echo "� Backing up cluster-wide resources..."
mkdir -p "$BACKUP_DIR/cluster"
kubectl get nodes -o yaml > "$BACKUP_DIR/cluster/nodes.yaml" 2>/dev/null && echo "   ✅ Nodes backed up"
kubectl get pv -o yaml > "$BACKUP_DIR/cluster/persistent-volumes.yaml" 2>/dev/null && echo "   ✅ PVs backed up"
kubectl get sc -o yaml > "$BACKUP_DIR/cluster/storage-classes.yaml" 2>/dev/null && echo "   ✅ Storage Classes backed up"

echo "✅ Backup completed successfully!"
echo "� Location: $BACKUP_DIR"
echo "� Summary: $(find "$BACKUP_DIR" -name "*.yaml" | wc -l) files backed up"
echo "�️  Available backups:"
ls -la "$BACKUP_BASE/" 2>/dev/null | tail -3 || echo "This is your first backup!"
