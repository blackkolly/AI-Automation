# ArgoCD Implementation Guide

This document provides step-by-step instructions for implementing ArgoCD for the microservices platform, including installation, configuration, and usage.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [ArgoCD Installation](#argocd-installation)
3. [Configuration](#configuration)
4. [Application Setup](#application-setup)
5. [Usage Guide](#usage-guide)
6. [Troubleshooting](#troubleshooting)
7. [Best Practices](#best-practices)

## Prerequisites

### Required Tools
- `kubectl` configured for your EKS cluster
- AWS CLI configured with appropriate permissions
- Access to the Kubernetes cluster
- Git repository access

### Cluster Requirements
- Kubernetes cluster (EKS) running
- GitOps namespace created: `kubectl create namespace gitops`
- Sufficient cluster resources for ArgoCD components

## ArgoCD Installation

### Step 1: Create GitOps Namespace

```bash
# Create gitops namespace if it doesn't exist
kubectl create namespace gitops --dry-run=client -o yaml | kubectl apply -f -
```

### Step 2: Install ArgoCD

```bash
# Install ArgoCD in gitops namespace
curl -s https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml | sed 's/namespace: argocd/namespace: gitops/g' | kubectl apply -n gitops -f -
```

### Step 3: Verify Installation

```bash
# Check all pods in gitops namespace
kubectl get pods -n gitops

# Wait for ArgoCD server to be ready
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n gitops
```

## Configuration

### Step 1: Expose ArgoCD UI

```bash
# Change ArgoCD server service to LoadBalancer
kubectl patch svc argocd-server -n gitops -p '{"spec": {"type": "LoadBalancer"}}'

# Check the service status
kubectl get svc argocd-server -n gitops
```

### Step 2: Get Admin Credentials

```bash
# Get the initial admin password
kubectl -n gitops get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Get the LoadBalancer URL
kubectl get svc argocd-server -n gitops -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### Step 3: Access ArgoCD UI

- **URL**: `http://[LoadBalancer-URL]`
- **Username**: `admin`
- **Password**: [from step 2]

### Alternative: Port Forward Access

```bash
# If LoadBalancer is not available, use port forwarding
kubectl port-forward svc/argocd-server -n gitops 8080:443

# Access at: https://localhost:8080
```

## Application Setup

### Step 1: Apply ArgoCD Applications

```bash
# Create microservices applications in ArgoCD
kubectl apply -f argocd/applications.yaml
```

### Step 2: Verify Applications

```bash
# Check if applications are created
kubectl get applications -n gitops

# Get detailed status
kubectl get applications -n gitops -o wide
```

### Step 3: Application Structure

The applications.yaml file creates two applications:

#### Production Application
- **Name**: `microservices-platform-production`
- **Source**: GitHub repository main branch
- **Path**: `Kubernetes_Project/microservices-platform/kubernetes/manifests`
- **Destination**: `default` namespace
- **Sync Policy**: Manual sync (for safety)

#### Staging Application
- **Name**: `microservices-platform-staging`
- **Source**: GitHub repository main branch
- **Path**: `Kubernetes_Project/microservices-platform/kubernetes/manifests`
- **Destination**: `staging` namespace
- **Sync Policy**: Automatic sync enabled

## Usage Guide

### Viewing Applications in ArgoCD UI

1. **Login** to ArgoCD UI with admin credentials
2. **Applications Dashboard** shows both applications:
   - microservices-platform-production
   - microservices-platform-staging
3. **Click on application** to see detailed resource tree
4. **View sync status** and health of all components

### Manual Sync

#### Via ArgoCD UI
1. Click on the application
2. Click the "SYNC" button
3. Select resources to sync (or sync all)
4. Click "SYNCHRONIZE"

#### Via Command Line
```bash
# Manually sync production application
kubectl patch application microservices-platform-production -n gitops -p '{"operation":{"sync":{}}}' --type=merge

# Manually sync staging application
kubectl patch application microservices-platform-staging -n gitops -p '{"operation":{"sync":{}}}' --type=merge
```

### Enable Auto-Sync

#### Via ArgoCD UI
1. Go to Application Settings
2. Enable "Auto-Sync"
3. Configure sync options:
   - Prune: Remove resources not in Git
   - Self Heal: Correct drift automatically

#### Via Command Line
```bash
# Enable auto-sync for production (use with caution)
kubectl patch application microservices-platform-production -n gitops -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}' --type=merge
```

### Application Health Monitoring

```bash
# Check application health
kubectl get application microservices-platform-production -n gitops -o jsonpath='{.status.health.status}'

# Check sync status
kubectl get application microservices-platform-production -n gitops -o jsonpath='{.status.sync.status}'

# View application resources
kubectl get application microservices-platform-production -n gitops -o jsonpath='{.status.resources[*].name}'
```

### Rollback Procedures

#### Via ArgoCD UI
1. Go to Application History
2. Select the previous revision
3. Click "ROLLBACK"

#### Via Command Line
```bash
# Rollback to previous revision
kubectl patch application microservices-platform-production -n gitops -p '{"operation":{"rollback":{"id":"[revision-id]"}}}' --type=merge
```

## Troubleshooting

### Common Issues and Solutions

#### Application Not Syncing

**Problem**: Application shows as "OutOfSync" but won't sync

**Solutions**:
```bash
# Check application status
kubectl describe application microservices-platform-production -n gitops

# Check ArgoCD controller logs
kubectl logs -n gitops deployment/argocd-application-controller

# Force refresh
kubectl patch application microservices-platform-production -n gitops -p '{"operation":{"refresh":{}}}' --type=merge
```

#### Repository Access Issues

**Problem**: ArgoCD cannot access Git repository

**Solutions**:
1. Verify repository URL in applications.yaml
2. Check repository permissions
3. Add SSH keys or credentials if private repository

#### Resource Conflicts

**Problem**: Resources already exist in cluster

**Solutions**:
```bash
# Check existing resources
kubectl get all -n default
kubectl get all -n staging

# Delete conflicting resources if safe
kubectl delete deployment [resource-name] -n [namespace]
```

#### ArgoCD UI Not Accessible

**Problem**: Cannot access ArgoCD web interface

**Solutions**:
```bash
# Check service status
kubectl get svc argocd-server -n gitops

# Check pod status
kubectl get pods -n gitops

# Check LoadBalancer external IP
kubectl get svc argocd-server -n gitops -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Use port forwarding as alternative
kubectl port-forward svc/argocd-server -n gitops 8080:443
```

### Debugging Commands

```bash
# Check ArgoCD components
kubectl get all -n gitops

# Check application controller logs
kubectl logs -n gitops deployment/argocd-application-controller --tail=50

# Check repo server logs
kubectl logs -n gitops deployment/argocd-repo-server --tail=50

# Check server logs
kubectl logs -n gitops deployment/argocd-server --tail=50

# Get application events
kubectl get events --field-selector involvedObject.name=microservices-platform-production -n gitops
```

## Best Practices

### Security

1. **Change Default Password**
   ```bash
   # Change admin password after first login
   argocd account update-password --account admin
   ```

2. **Enable RBAC**
   - Configure role-based access control for team members
   - Use least privilege principle

3. **Use Private Repositories**
   - Store sensitive configurations in private Git repositories
   - Configure proper authentication for private repos

### Operations

1. **Environment Separation**
   - Use different namespaces for different environments
   - Production applications should have manual sync for safety
   - Staging can use auto-sync for faster iteration

2. **Monitoring**
   ```bash
   # Regular health checks
   kubectl get applications -n gitops -o wide
   
   # Monitor sync status
   watch kubectl get applications -n gitops
   ```

3. **Backup and Recovery**
   ```bash
   # Backup ArgoCD configuration
   kubectl get applications -n gitops -o yaml > argocd-applications-backup.yaml
   
   # Export application configurations
   kubectl get application microservices-platform-production -n gitops -o yaml > production-app-backup.yaml
   ```

### GitOps Workflow

1. **Git as Source of Truth**
   - All changes should go through Git
   - Avoid manual kubectl commands on managed resources
   - Use pull requests for changes

2. **Branch Strategy**
   - Use `main` branch for production deployments
   - Use `develop` or feature branches for staging
   - Tag releases for easy rollbacks

3. **Change Management**
   - Review all changes through pull requests
   - Test changes in staging before production
   - Use ArgoCD notifications for deployment alerts

## Integration with CI/CD

### With GitHub Actions

ArgoCD complements but doesn't replace CI/CD pipelines:

- **CI/CD Role**: Build, test, and push container images
- **ArgoCD Role**: Deploy applications based on Git state

### Image Updates

```bash
# Update image tags in Kubernetes manifests
kubectl patch deployment api-gateway -p '{"spec":{"template":{"spec":{"containers":[{"name":"api-gateway","image":"779066052352.dkr.ecr.us-east-1.amazonaws.com/api-gateway:v1.2.0"}]}}}}' --dry-run=client -o yaml

# Commit changes to Git
git add kubernetes/manifests/
git commit -m "Update api-gateway to v1.2.0"
git push

# ArgoCD will automatically sync the changes (if auto-sync is enabled)
```

## Useful Commands Reference

### Application Management
```bash
# List all applications
kubectl get applications -n gitops

# Describe application
kubectl describe application [app-name] -n gitops

# Get application status
kubectl get application [app-name] -n gitops -o yaml

# Delete application
kubectl delete application [app-name] -n gitops
```

### Sync Operations
```bash
# Manual sync
kubectl patch application [app-name] -n gitops -p '{"operation":{"sync":{}}}' --type=merge

# Refresh application
kubectl patch application [app-name] -n gitops -p '{"operation":{"refresh":{}}}' --type=merge

# Hard refresh
kubectl patch application [app-name] -n gitops -p '{"operation":{"refresh":{"hard":true}}}' --type=merge
```

### Monitoring
```bash
# Watch applications
watch kubectl get applications -n gitops

# Get application resources
kubectl get application [app-name] -n gitops -o jsonpath='{.status.resources[*]}'

# Check application health
kubectl get application [app-name] -n gitops -o jsonpath='{.status.health}'
```

## Conclusion

ArgoCD provides a powerful GitOps solution for managing Kubernetes deployments. This implementation guide covers:

- ✅ Complete ArgoCD installation in gitops namespace
- ✅ Application configuration for production and staging environments  
- ✅ Manual and automatic sync strategies
- ✅ Troubleshooting and monitoring procedures
- ✅ Security and operational best practices

With ArgoCD properly configured, your microservices platform now has:
- **Declarative deployments** based on Git state
- **Visual monitoring** of application health and sync status
- **Easy rollback** capabilities to any previous state
- **Automated drift detection** and correction
- **Centralized deployment management** through a web UI

For ongoing operations, monitor applications through the ArgoCD UI and use the provided commands for troubleshooting and management tasks.
