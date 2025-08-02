# ArgoCD Setup for Microservices Platform

## Quick Installation

Run the installation script:

```bash
chmod +x scripts/install-argocd.sh
./scripts/install-argocd.sh
```

This will:
- ✅ Install ArgoCD in your EKS cluster
- ✅ Expose ArgoCD UI via LoadBalancer  
- ✅ Generate admin credentials
- ✅ Save access information

## Manual Installation Steps

If you prefer manual installation:

### 1. Install ArgoCD

```bash
# Create ArgoCD namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods to be ready
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd
```

### 2. Expose ArgoCD UI

```bash
# Change service to LoadBalancer
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Get LoadBalancer URL
kubectl get svc argocd-server -n argocd
```

### 3. Get Admin Password

```bash
# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Create Applications

### 1. Apply ArgoCD Applications

```bash
# Create applications for your microservices
kubectl apply -f argocd/applications.yaml
```

### 2. Access ArgoCD UI

**Option A: LoadBalancer (Recommended)**
- URL: http://[LoadBalancer-URL]
- Username: `admin`
- Password: [Generated password]

**Option B: Port Forward**
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```
- URL: https://localhost:8080
- Username: `admin`  
- Password: [Generated password]

## ArgoCD Applications Created

### 1. Production Application
- **Name**: `microservices-platform-production`
- **Source**: GitHub repo main branch
- **Destination**: `default` namespace
- **Sync**: Manual (for safety)

### 2. Staging Application  
- **Name**: `microservices-platform-staging`
- **Source**: GitHub repo main branch
- **Destination**: `staging` namespace
- **Sync**: Automatic

## Using ArgoCD

### View Applications
1. Login to ArgoCD UI
2. See all your microservices as applications
3. Visual representation of deployment status

### Manual Sync
1. Click on application
2. Click "SYNC" button
3. Select resources to sync
4. Click "SYNCHRONIZE"

### Enable Auto-Sync
1. Go to Application Settings
2. Enable "Auto-Sync"
3. Choose sync options

### Rollback
1. Go to Application History
2. Select previous revision
3. Click "ROLLBACK"

## Benefits for Your Platform

✅ **Visual Dashboard** - See all services at a glance  
✅ **Git as Source of Truth** - Deploy what's in Git  
✅ **Easy Rollbacks** - Click to rollback to any version  
✅ **Automatic Sync** - Keep cluster in sync with Git  
✅ **No CI/CD Complexity** - Just pure deployment  
✅ **Drift Detection** - See when cluster differs from Git  

## Repository Structure

Your repository is automatically tracked:
```
Kubernetes_Project/microservices-platform/kubernetes/manifests/
├── api-gateway-deployment.yaml
├── auth-service-deployment.yaml  
├── order-service-deployment.yaml
├── product-service-deployment.yaml
├── frontend-deployment.yaml
└── ... (other manifests)
```

## Workflow

1. **Make Changes**: Edit Kubernetes manifests in Git
2. **Commit & Push**: Push changes to GitHub
3. **ArgoCD Syncs**: ArgoCD automatically deploys changes
4. **Monitor**: Watch deployment in ArgoCD UI
5. **Rollback**: If needed, rollback with one click

## Security Notes

- Change default admin password after first login
- Consider enabling RBAC for team access
- Use Git webhooks for faster sync (optional)
- Enable SSL/TLS for production use

## Troubleshooting

### Application Not Syncing
```bash
# Check application status
kubectl get application -n argocd

# Check ArgoCD controller logs
kubectl logs -n argocd deployment/argocd-application-controller
```

### UI Not Accessible
```bash
# Check service status
kubectl get svc argocd-server -n argocd

# Check pod status  
kubectl get pods -n argocd
```

### Sync Errors
1. Check application details in UI
2. Look at sync status and errors
3. Verify Kubernetes manifests are valid
4. Check resource quotas and permissions

## Next Steps

1. **Install ArgoCD** - Run the installation script
2. **Access UI** - Login and explore the interface  
3. **Create Applications** - Apply the application manifests
4. **Test Sync** - Make a small change and watch it deploy
5. **Enable Auto-Sync** - Let ArgoCD manage deployments automatically

ArgoCD is perfect for your stable platform - it gives you GitOps without the complexity!
