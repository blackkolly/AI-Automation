# Backup and Disaster Recovery System

## Overview

This comprehensive backup and disaster recovery system provides enterprise-grade data protection for your Kubernetes microservices platform. The system includes automated backups, monitoring, alerting, and disaster recovery capabilities.

## Architecture

### Components

1. **Velero** - Cluster-wide backup and restore
2. **ETCD Backup** - Kubernetes cluster state backup
3. **MongoDB Backup** - Database backup and restore
4. **Monitoring** - Metrics, alerting, and health checks
5. **Dashboard** - Web-based status monitoring

### Backup Types

#### 1. Velero Cluster Backup
- **Purpose**: Full cluster backup including resources, configurations, and persistent volumes
- **Schedule**: Daily at 2:00 AM
- **Retention**: 7 days (daily), 30 days (weekly), 90 days (disaster recovery)
- **Storage**: S3-compatible storage

#### 2. ETCD Backup
- **Purpose**: Kubernetes cluster state and configuration
- **Schedule**: Every 6 hours
- **Retention**: 7 days
- **Storage**: Local PVC + S3 upload

#### 3. MongoDB Backup
- **Purpose**: Application database backup
- **Schedule**: Daily at 2:00 AM
- **Retention**: 7 days
- **Storage**: Local PVC + S3 upload

## Installation

### Prerequisites

1. Kubernetes cluster with admin access
2. Helm 3.x installed
3. AWS CLI configured (for S3 storage)
4. Sufficient storage for backups

### Quick Start

```bash
# 1. Deploy the backup system
./backup-dr-manager.sh deploy

# 2. Configure storage credentials
kubectl create secret generic backup-storage-secret \
  --from-literal=aws-access-key-id=YOUR_ACCESS_KEY \
  --from-literal=aws-secret-access-key=YOUR_SECRET_KEY \
  -n velero

# 3. Verify installation
./backup-dr-manager.sh status

# 4. Access dashboard
kubectl port-forward svc/backup-dashboard-service 8080:80 -n backup-monitoring
# Open http://localhost:8080
```

### Detailed Installation

#### 1. Install Velero

```bash
# Apply Velero manifests
kubectl apply -f velero/velero-deployment.yaml
kubectl apply -f velero/backup-schedules.yaml

# Wait for Velero to be ready
kubectl wait --for=condition=available --timeout=300s deployment/velero -n velero
```

#### 2. Install ETCD Backup

```bash
# Apply ETCD backup manifests
kubectl apply -f etcd-backup/etcd-backup.yaml

# Verify ETCD backup job
kubectl get cronjob etcd-backup -n kube-system
```

#### 3. Install Database Backup

```bash
# Apply MongoDB backup manifests
kubectl apply -f database-backup/mongodb-backup.yaml

# Verify MongoDB backup job
kubectl get cronjob mongodb-backup -n microservices
```

#### 4. Install Monitoring

```bash
# Apply monitoring manifests
kubectl apply -f monitoring/backup-monitoring.yaml

# Access dashboard at NodePort 32000
curl http://your-cluster-ip:32000
```

## Configuration

### Storage Configuration

#### S3 Storage Setup

1. Create S3 buckets:
   - `kubernetes-backup` (Velero)
   - `kubernetes-etcd-backups` (ETCD)
   - `kubernetes-mongodb-backups` (MongoDB)

2. Configure IAM permissions:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::kubernetes-backup/*",
                "arn:aws:s3:::kubernetes-etcd-backups/*",
                "arn:aws:s3:::kubernetes-mongodb-backups/*"
            ]
        }
    ]
}
```

3. Update secrets with credentials:
```bash
# Velero credentials
kubectl patch secret cloud-credentials -n velero --patch='
data:
  cloud: base64_encoded_credentials_file
'

# ETCD backup credentials
kubectl patch secret etcd-backup-secret -n kube-system --patch='
data:
  aws-access-key-id: base64_encoded_access_key
  aws-secret-access-key: base64_encoded_secret_key
'

# MongoDB backup credentials
kubectl patch secret mongodb-backup-secret -n microservices --patch='
data:
  aws-access-key-id: base64_encoded_access_key
  aws-secret-access-key: base64_encoded_secret_key
'
```

### Backup Schedules

#### Velero Schedules
- **Daily**: `0 2 * * *` - Namespaces: microservices, default, kube-system
- **Weekly**: `0 3 * * 0` - Full cluster including ArgoCD, Istio, monitoring
- **MongoDB**: `0 1 * * *` - MongoDB-specific with hooks
- **Critical Systems**: `0 4 * * *` - kube-system, ArgoCD, Istio
- **Disaster Recovery**: `0 1 * * 6` - Full cluster, 90-day retention

#### ETCD Schedule
- **Backup**: Every 6 hours (`0 */6 * * *`)
- **Health Check**: Every 15 minutes

#### MongoDB Schedule
- **Backup**: Daily at 2 AM (`0 2 * * *`)
- **Health Check**: Every 15 minutes
- **App Data**: Daily at 3 AM (`0 3 * * *`)

## Operations

### Manual Backup Operations

#### Create Manual Backup

```bash
# Full cluster backup
./backup-dr-manager.sh backup --type=full --name=manual-backup

# Specific namespace backup
./backup-dr-manager.sh backup --type=namespace --namespace=microservices --name=microservices-backup

# Database backup
./backup-dr-manager.sh backup --type=database --name=db-backup
```

#### Velero Manual Backup

```bash
# Create backup
velero backup create manual-backup --include-namespaces microservices

# Check status
velero backup describe manual-backup

# Download logs
velero backup logs manual-backup
```

### Restore Operations

#### Full Cluster Restore

```bash
# List available backups
./backup-dr-manager.sh list-backups

# Restore from backup
./backup-dr-manager.sh restore --backup=backup-name --type=full

# Monitor restore progress
./backup-dr-manager.sh restore-status
```

#### Velero Restore

```bash
# Create restore from backup
velero restore create restore-1 --from-backup daily-backup-20231201-020000

# Check restore status
velero restore describe restore-1

# Get restore logs
velero restore logs restore-1
```

#### Database Restore

```bash
# List MongoDB backups
kubectl get jobs -n microservices -l app=mongodb-backup

# Restore from specific backup
kubectl create job mongodb-restore-manual --from=cronjob/mongodb-backup -n microservices
# Then edit the job to set BACKUP_FILE environment variable

# Monitor restore
kubectl logs -f job/mongodb-restore-manual -n microservices
```

#### ETCD Restore

⚠️ **WARNING**: ETCD restore requires cluster downtime and should be performed with extreme caution.

```bash
# Stop all master nodes first
# Then run restore job
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: etcd-restore-manual
  namespace: kube-system
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: etcd-restore
        image: bitnami/etcd:3.5.9
        env:
        - name: BACKUP_FILE
          value: "/backup/etcd-backup-YYYYMMDD_HHMMSS.db.gz"
        # ... (rest of the restore job configuration)
EOF
```

### Disaster Recovery Procedures

#### RTO/RPO Targets
- **RTO (Recovery Time Objective)**: < 4 hours
- **RPO (Recovery Point Objective)**: < 24 hours

#### DR Test Schedule
- **Frequency**: Monthly
- **Scope**: Full system restore in isolated environment
- **Validation**: Application functionality, data integrity

#### Emergency Procedures

1. **Assess the situation**
   - Determine scope of failure
   - Identify affected components
   - Estimate data loss

2. **Execute recovery plan**
   ```bash
   # Emergency restore script
   ./backup-dr-manager.sh emergency-restore
   ```

3. **Validate recovery**
   - Check application availability
   - Verify data integrity
   - Test critical functions

4. **Resume operations**
   - Update monitoring
   - Notify stakeholders
   - Document incident

## Monitoring and Alerting

### Metrics

The system exposes Prometheus metrics:

- `backup_last_success_timestamp` - Last successful backup timestamp
- `backup_size_bytes` - Backup size in bytes
- `backup_duration_seconds` - Backup duration
- `backup_total_count` - Total backup count by status
- `backup_age_hours` - Age of latest backup
- `backup_health_status` - Overall health status

### Dashboard

Access the backup dashboard:
- **URL**: `http://cluster-ip:32000`
- **Features**: Status overview, metrics, manual actions
- **Auto-refresh**: Every 5 minutes

### Alerts

Configured alerts:
- **BackupFailed**: Critical alert when backup fails
- **BackupTooOld**: Warning when backup is over 25 hours old
- **NoRecentBackups**: Critical alert for no backups in 24 hours
- **BackupStorageFull**: Warning when storage exceeds 50GB

## Troubleshooting

### Common Issues

#### Velero Backup Failures

```bash
# Check Velero logs
kubectl logs deployment/velero -n velero

# Check backup status
velero backup get
velero backup describe <backup-name>

# Check storage location
velero backup-location get
```

#### ETCD Backup Issues

```bash
# Check ETCD backup job
kubectl get cronjob etcd-backup -n kube-system
kubectl describe cronjob etcd-backup -n kube-system

# Check recent job runs
kubectl get jobs -n kube-system -l app=etcd-backup

# Check logs
kubectl logs job/<job-name> -n kube-system
```

#### MongoDB Backup Problems

```bash
# Check MongoDB backup job
kubectl get cronjob mongodb-backup -n microservices

# Check MongoDB connectivity
kubectl exec -it <mongodb-pod> -n microservices -- mongo --eval "db.adminCommand('ping')"

# Check backup logs
kubectl logs job/<mongodb-backup-job> -n microservices
```

#### Storage Issues

```bash
# Check PVC status
kubectl get pvc -n velero
kubectl get pvc -n kube-system
kubectl get pvc -n microservices

# Check storage usage
kubectl exec -it <backup-pod> -- df -h /backup

# Check S3 connectivity
kubectl exec -it <backup-pod> -- aws s3 ls s3://kubernetes-backup/
```

### Performance Tuning

#### Velero Optimization

```yaml
# Increase concurrent backups
spec:
  template:
    spec:
      args:
      - --default-backup-storage-location=default
      - --backup-sync-period=60m
      - --fs-backup-timeout=240m
      - --concurrent-node-backups=3
```

#### Resource Allocation

```yaml
# Increase backup job resources
resources:
  requests:
    memory: "512Mi"
    cpu: "200m"
  limits:
    memory: "2Gi"
    cpu: "1000m"
```

## Security

### Encryption
- **At Rest**: All backups encrypted using AES-256
- **In Transit**: TLS encryption for all backup transfers
- **Credentials**: Stored in Kubernetes secrets

### Access Control
- **RBAC**: Minimal required permissions
- **Service Accounts**: Dedicated accounts per component
- **Network Policies**: Restricted backup traffic

### Compliance
- **Retention**: Configurable retention policies
- **Audit**: All backup operations logged
- **Documentation**: Comprehensive disaster recovery documentation

## Maintenance

### Regular Tasks

#### Weekly
- Review backup success rates
- Check storage usage
- Validate monitoring alerts

#### Monthly
- Perform disaster recovery test
- Review and update documentation
- Check credential expiration

#### Quarterly
- Review retention policies
- Update backup strategies
- Security audit

### Capacity Planning

Monitor these metrics:
- Backup storage growth rate
- Backup duration trends
- Network bandwidth usage
- Compute resource consumption

## Support

### Emergency Contacts
- **Primary**: DevOps Team
- **Secondary**: Platform Engineering
- **Escalation**: CTO Office

### Documentation Links
- [Velero Documentation](https://velero.io/docs/)
- [ETCD Backup Guide](https://etcd.io/docs/v3.5/op-guide/recovery/)
- [MongoDB Backup Documentation](https://docs.mongodb.com/manual/tutorial/backup-and-restore-tools/)

### Training Resources
- Disaster recovery runbooks
- Backup verification procedures
- Emergency response protocols
