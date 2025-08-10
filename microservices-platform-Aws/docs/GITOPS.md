# GitOps Configuration

This directory contains GitOps configuration and deployment automation for the microservices platform.

## Architecture

The GitOps pipeline consists of:

1. **GitHub Actions Workflows** - Automated CI/CD pipelines
2. **ArgoCD Applications** - Declarative GitOps deployments
3. **Deployment Scripts** - Manual deployment tools
4. **Environment Management** - Staging and production environments

## GitHub Actions Workflows

### Main CI/CD Pipeline (`ci-cd.yaml`)

**Triggers:**

- Push to `main` branch → Production deployment
- Push to `develop` branch → Staging deployment
- Pull requests → Testing and validation

**Pipeline Stages:**

1. **Change Detection** - Identifies which services have changes
2. **Testing**
   - Node.js services: lint, test, security audit
   - Java service: Maven tests, dependency check
3. **Build & Push** - Docker images to ECR with caching
4. **Security Scanning** - Trivy vulnerability scans
5. **Deployment**
   - Staging: Automatic on develop branch
   - Production: Automatic on main branch with approval
6. **Health Checks** - Comprehensive service validation
7. **Notifications** - Slack alerts on deployment status

### Manual Deployment (`manual-deploy.yaml`)

Provides on-demand deployment capabilities:

- Choose environment (staging/production)
- Select specific service or deploy all
- Specify custom image tags

### Rollback Workflow (`rollback.yaml`)

Quick rollback functionality:

- Select service and environment
- Automatic rollback to previous revision
- Or specify target revision number

## ArgoCD Configuration

### Applications (`argocd/applications.yaml`)

- **microservices-platform**: Production app tracking main branch
- **microservices-platform-staging**: Staging app tracking develop branch

**Features:**

- Automated sync with self-healing
- Pruning of removed resources
- Retry logic with backoff
- Revision history tracking

## Deployment Scripts

### GitOps Deploy Script (`scripts/gitops-deploy.sh`)

Comprehensive deployment automation tool:

```bash
# Setup environment
./gitops-deploy.sh setup

# Build specific service
./gitops-deploy.sh build api-gateway v1.0.0

# Deploy service
./gitops-deploy.sh deploy auth-service latest staging

# Full deployment
./gitops-deploy.sh full-deploy v1.0.0

# Health checks
./gitops-deploy.sh health staging

# Rollback
./gitops-deploy.sh rollback order-service default 2
```

## Environment Setup

### Required Secrets

Configure these secrets in GitHub repository settings:

```
AWS_ACCESS_KEY_ID       - AWS access key for ECR and EKS
AWS_SECRET_ACCESS_KEY   - AWS secret key
SLACK_WEBHOOK_URL       - Slack notifications (optional)
```

### Environment Variables

```bash
AWS_REGION=us-east-1
ECR_REGISTRY=779066052352.dkr.ecr.us-east-1.amazonaws.com
EKS_CLUSTER_NAME=microservices-platform-prod
```

## Deployment Strategies

### 1. Feature Development Flow

```
feature-branch → develop → staging → main → production
```

1. Create feature branch from develop
2. Push triggers testing pipeline
3. Merge to develop triggers staging deployment
4. Merge to main triggers production deployment

### 2. Hotfix Flow

```
hotfix-branch → main → production
```

1. Create hotfix branch from main
2. Test and deploy directly to production
3. Merge back to develop

### 3. Manual Deployment

Use manual deployment workflow for:

- Emergency deployments
- Specific version deployments
- Testing new features

## Monitoring and Observability

### Health Checks

The pipeline includes comprehensive health checks:

1. **Pod Status** - Verify all pods are running
2. **Service Endpoints** - Check service discovery
3. **LoadBalancer** - Test external connectivity
4. **API Health** - Validate service responses

### Rollback Procedures

**Automatic Rollback Triggers:**

- Health check failures
- Pod crash loops
- Service unavailability

**Manual Rollback:**

1. Use rollback workflow in GitHub Actions
2. Or use gitops-deploy.sh script
3. Or kubectl rollout undo commands

## Security

### Image Scanning

- **Trivy** scans all Docker images
- Security findings uploaded to GitHub Security tab
- Failed scans block production deployments

### Access Control

- **Environment Protection Rules** require approvals for production
- **RBAC** controls Kubernetes access
- **AWS IAM** limits ECR and EKS permissions

## Best Practices

### Image Tagging Strategy

```
latest                  - Latest build on main
main-<sha>             - Main branch builds
develop-<sha>          - Develop branch builds
v1.0.0                 - Release tags
```

### Deployment Validation

1. Always test in staging first
2. Use rolling deployments for zero downtime
3. Monitor logs during deployments
4. Validate health checks before proceeding

### Troubleshooting

**Common Issues:**

1. **ECR Login Failures**

   ```bash
   aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 779066052352.dkr.ecr.us-east-1.amazonaws.com
   ```

2. **kubectl Access Issues**

   ```bash
   aws eks update-kubeconfig --region us-east-1 --name microservices-platform-prod
   ```

3. **Deployment Stuck**

   ```bash
   kubectl rollout status deployment/<service> --timeout=300s
   kubectl describe deployment <service>
   kubectl logs -l app=<service>
   ```

4. **Pod Not Ready**
   ```bash
   kubectl describe pod <pod-name>
   kubectl logs <pod-name>
   kubectl get events --sort-by=.metadata.creationTimestamp
   ```

## Migration from Manual to GitOps

### Phase 1: Setup CI/CD

1. Configure GitHub secrets
2. Test workflows on feature branches
3. Validate staging deployments

### Phase 2: Production Migration

1. Deploy current state via GitOps
2. Verify all services are healthy
3. Switch DNS to GitOps-managed services

### Phase 3: Advanced Features

1. Install ArgoCD for declarative GitOps
2. Configure monitoring and alerting
3. Implement progressive deployments
