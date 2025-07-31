# Deployment Guide

This guide provides step-by-step instructions for deploying the production-grade microservices platform on AWS EKS.

## Prerequisites

### Required Tools
```bash
# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install Terraform
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Install Docker
sudo apt-get update
sudo apt-get install docker.io
sudo usermod -aG docker $USER
```

### AWS Configuration
```bash
# Configure AWS credentials
aws configure
# Enter your AWS Access Key ID, Secret Access Key, Region (us-west-2), and output format (json)

# Verify configuration
aws sts get-caller-identity
```

## Phase 1: Infrastructure Deployment

### Step 1: Deploy AWS Infrastructure with Terraform

```bash
# Navigate to Terraform directory
cd infrastructure/terraform

# Copy and customize variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your specific values

# Set required secrets as environment variables
export TF_VAR_db_password="your-secure-db-password"
export TF_VAR_redis_auth_token="your-redis-auth-token"
export TF_VAR_grafana_admin_password="your-grafana-password"
export TF_VAR_argocd_admin_password="your-argocd-password"

# Initialize Terraform
terraform init

# Plan the deployment
terraform plan

# Apply the infrastructure
terraform apply
```

### Step 2: Configure kubectl

```bash
# Update kubeconfig for the new cluster
aws eks update-kubeconfig --region us-west-2 --name microservices-platform-dev

# Verify cluster connection
kubectl get nodes
kubectl get namespaces
```

## Phase 2: Container Images

### Step 1: Build and Push Images to ECR

```bash
# Login to ECR
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-west-2.amazonaws.com

# Build and push each service
for service in auth-service api-gateway product-service order-service; do
  cd services/$service
  docker build -t $service:latest .
  docker tag $service:latest <account-id>.dkr.ecr.us-west-2.amazonaws.com/$service:latest
  docker push <account-id>.dkr.ecr.us-west-2.amazonaws.com/$service:latest
  cd ../..
done
```

### Step 2: Update Kubernetes Manifests

```bash
# Update image references in manifests
sed -i "s/your-account/<your-actual-account-id>/g" kubernetes/manifests/*.yaml
```

## Phase 3: Security and Secrets

### Step 1: Create Kubernetes Secrets

```bash
# Create secrets for database
kubectl create secret generic postgres-secret \
  --from-literal=username=postgres \
  --from-literal=password=$TF_VAR_db_password \
  -n microservices

# Create Redis auth secret
kubectl create secret generic redis-secret \
  --from-literal=auth-token=$TF_VAR_redis_auth_token \
  -n microservices

# Create JWT secret
kubectl create secret generic jwt-secret \
  --from-literal=jwt-secret=$(openssl rand -base64 32) \
  -n microservices

# Create OAuth secrets (replace with your actual values)
kubectl create secret generic oauth-secrets \
  --from-literal=google-client-id=your-google-client-id \
  --from-literal=google-client-secret=your-google-client-secret \
  --from-literal=github-client-id=your-github-client-id \
  --from-literal=github-client-secret=your-github-client-secret \
  -n microservices

# Create ECR registry secret
kubectl create secret docker-registry ecr-registry-secret \
  --docker-server=<account-id>.dkr.ecr.us-west-2.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password --region us-west-2) \
  -n microservices
```

### Step 2: Update ConfigMap

```bash
# Update ConfigMap with actual endpoints from Terraform output
kubectl apply -f kubernetes/manifests/config.yaml
```

## Phase 4: Deploy Core Services

### Step 1: Deploy Namespaces and Configuration

```bash
# Create namespaces
kubectl apply -f kubernetes/manifests/namespaces.yaml

# Apply configuration
kubectl apply -f kubernetes/manifests/config.yaml
```

### Step 2: Deploy Microservices

```bash
# Deploy all services
kubectl apply -f kubernetes/manifests/auth-service.yaml
kubectl apply -f kubernetes/manifests/api-gateway.yaml
kubectl apply -f kubernetes/manifests/product-service.yaml
kubectl apply -f kubernetes/manifests/order-service.yaml

# Verify deployments
kubectl get pods -n microservices
kubectl get svc -n microservices
```

## Phase 5: Monitoring Stack

### Step 1: Install Monitoring Components

```bash
# Make script executable and run
chmod +x kubernetes/monitoring/install-monitoring.sh
./kubernetes/monitoring/install-monitoring.sh

# Verify monitoring stack
kubectl get pods -n monitoring
```

### Step 2: Access Monitoring Dashboards

```bash
# Prometheus
kubectl port-forward svc/prometheus-stack-kube-prom-prometheus 9090:9090 -n monitoring

# Grafana (admin/admin123)
kubectl port-forward svc/prometheus-stack-grafana 3000:80 -n monitoring

# Jaeger
kubectl port-forward svc/jaeger-query 16686:16686 -n monitoring
```

## Phase 6: Security Stack

### Step 1: Install Security Components

```bash
# Make script executable and run
chmod +x kubernetes/security/install-security.sh
./kubernetes/security/install-security.sh

# Verify security stack
kubectl get pods -n security
```

### Step 2: Apply Security Policies

```bash
# Apply network policies
kubectl apply -f kubernetes/security/network-policies.yaml

# Verify network policies
kubectl get networkpolicies -A
```

## Phase 7: GitOps with ArgoCD

### Step 1: Install ArgoCD

```bash
# Make script executable and run
chmod +x kubernetes/gitops/install-argocd.sh
./kubernetes/gitops/install-argocd.sh

# Get ArgoCD admin password
kubectl -n gitops get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Step 2: Configure GitOps Applications

```bash
# Apply ArgoCD applications
kubectl apply -f kubernetes/gitops/argocd-applications.yaml

# Access ArgoCD UI
kubectl port-forward svc/argocd-server 8080:443 -n gitops
# Visit https://localhost:8080
```

## Phase 8: Service Mesh (Istio)

### Step 1: Install Istio

```bash
# Download Istio
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH

# Install Istio
istioctl install --set values.defaultRevision=default

# Enable automatic sidecar injection
kubectl label namespace microservices istio-injection=enabled

# Restart deployments to inject sidecars
kubectl rollout restart deployment -n microservices
```

## Phase 9: Load Testing and Validation

### Step 1: Verify All Components

```bash
# Check all pods are running
kubectl get pods -A

# Check services
kubectl get svc -A

# Check ingress
kubectl get ingress -A

# Test API endpoints
curl -k https://$(kubectl get svc api-gateway -n microservices -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')/health
```

### Step 2: Run Integration Tests

```bash
# Install test dependencies
cd tests/integration
npm install

# Run tests
npm test
```

## Phase 10: Production Considerations

### Security Hardening

```bash
# Enable Pod Security Standards
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: microservices
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
EOF

# Apply resource quotas
kubectl apply -f - <<EOF
apiVersion: v1
kind: ResourceQuota
metadata:
  name: microservices-quota
  namespace: microservices
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    persistentvolumeclaims: "10"
EOF
```

### Backup Configuration

```bash
# Setup automated backups with Velero
helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts/
helm install velero vmware-tanzu/velero \
  --namespace velero \
  --create-namespace \
  --set configuration.provider=aws \
  --set configuration.backupStorageLocation.bucket=your-backup-bucket \
  --set configuration.backupStorageLocation.config.region=us-west-2 \
  --set configuration.volumeSnapshotLocation.config.region=us-west-2 \
  --set initContainers[0].name=velero-plugin-for-aws \
  --set initContainers[0].image=velero/velero-plugin-for-aws:v1.8.0 \
  --set initContainers[0].volumeMounts[0].mountPath=/target \
  --set initContainers[0].volumeMounts[0].name=plugins
```

### Monitoring and Alerting

```bash
# Setup Slack notifications (replace with your webhook)
kubectl create secret generic slack-webhook \
  --from-literal=url=https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK \
  -n monitoring

# Configure PagerDuty (if used)
kubectl create secret generic pagerduty-config \
  --from-literal=integration-key=your-pagerduty-key \
  -n monitoring
```

## Troubleshooting

### Common Issues

1. **Pods stuck in Pending state**
   ```bash
   kubectl describe pod <pod-name> -n microservices
   # Check events for resource constraints or node selector issues
   ```

2. **Service discovery issues**
   ```bash
   kubectl get endpoints -n microservices
   kubectl get svc -n microservices
   ```

3. **Database connection issues**
   ```bash
   # Check security groups allow traffic on port 5432
   # Verify RDS endpoint in ConfigMap
   kubectl get configmap app-config -n microservices -o yaml
   ```

4. **Image pull errors**
   ```bash
   # Refresh ECR token
   kubectl delete secret ecr-registry-secret -n microservices
   kubectl create secret docker-registry ecr-registry-secret \
     --docker-server=<account-id>.dkr.ecr.us-west-2.amazonaws.com \
     --docker-username=AWS \
     --docker-password=$(aws ecr get-login-password --region us-west-2) \
     -n microservices
   ```

### Useful Commands

```bash
# View logs
kubectl logs -f deployment/auth-service -n microservices

# Scale services
kubectl scale deployment auth-service --replicas=5 -n microservices

# Update deployments
kubectl rollout restart deployment/auth-service -n microservices

# Check resource usage
kubectl top pods -n microservices
kubectl top nodes
```

## Cleanup

To destroy the entire infrastructure:

```bash
# Delete Kubernetes resources
kubectl delete namespace microservices monitoring security gitops kafka logging

# Destroy Terraform infrastructure
cd infrastructure/terraform
terraform destroy
```

## Next Steps

1. Set up DNS records for your domain
2. Configure SSL certificates
3. Set up log aggregation
4. Configure backup strategies
5. Set up disaster recovery procedures
6. Implement cost optimization strategies
7. Set up performance testing
8. Configure compliance scanning

For support, refer to the individual component documentation or create an issue in the repository.
